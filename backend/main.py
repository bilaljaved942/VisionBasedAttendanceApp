import os
import io
import json
import httpx
import numpy as np
import redis
import face_recognition
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client, Client
from PIL import Image, ImageOps

app = FastAPI(title="FAST Attendance Face Recognition API")

def load_image_file_upright(file, mode='RGB'):
    im = Image.open(file)
    im = ImageOps.exif_transpose(im)
    if mode:
        im = im.convert(mode)
    return np.array(im)


# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load environment configs from a shared .env file or environment variables
try:
    from dotenv import load_dotenv
    # Look for .env in app directory
    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../app/.env"))
except ImportError:
    pass

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Warning: SUPABASE_URL or SUPABASE_ANON_KEY environment variables not set.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Connect to local Redis
try:
    r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
except Exception as e:
    print(f"Warning: Failed to connect to Redis on localhost:6379. Make sure Redis is running. Error: {e}")
    r = None

async def get_course_student_encodings(course_id: str):
    if r is None:
        print("Warning: Redis is not connected. Returning empty encodings.")
        return {}

    # Check if cached in Redis hash
    cache_key = f"course:{course_id}"
    try:
        cached_data = r.hgetall(cache_key)
        if cached_data:
            encodings = {}
            for student_id, encoding_json in cached_data.items():
                encodings[student_id] = np.array(json.loads(encoding_json))
            print(f"Redis Cache Hit: Loaded {len(encodings)} student encodings for course {course_id}.")
            return encodings
    except Exception as e:
        print(f"Redis read error: {e}")

    # Cache Miss: Fetch from Supabase
    encodings = {}
    try:
        print(f"Redis Cache Miss: Loading student face encodings from Supabase for course {course_id}...")
        # 1. Fetch enrollments for the course
        response = supabase.table("enrollments").select("student_id").eq("course_id", course_id).execute()
        student_ids = [row["student_id"] for row in response.data]
        print(f"Found {len(student_ids)} enrolled student(s) in course {course_id}: {student_ids}")

        if student_ids:
            # 2. Fetch profiles for these students to get their face_url
            profiles_response = supabase.table("profiles").select("id, name, face_url").in_("id", student_ids).execute()
            print(f"Fetched {len(profiles_response.data)} student profiles from Supabase.")
            
            for profile in profiles_response.data:
                student_id = profile["id"]
                name = profile.get("name", "Unknown")
                face_url = profile.get("face_url")
                if not face_url:
                    print(f"⚠️ Student {name} (ID: {student_id}) has no registered face image URL in profile.")
                    continue
                
                print(f"Downloading registered face image for student {name}... URL: {face_url}")
                # 3. Download the registered face image from Supabase Storage
                async with httpx.AsyncClient(timeout=10.0) as client:
                    img_response = await client.get(face_url)
                    if img_response.status_code == 200:
                        img_bytes = img_response.content
                        img_file = io.BytesIO(img_bytes)
                        # Load image with face_recognition and extract 128-d encoding vector
                        student_image = load_image_file_upright(img_file)
                        student_encodings = face_recognition.face_encodings(student_image)
                        if student_encodings:
                            encoding = student_encodings[0]
                            encodings[student_id] = encoding
                            print(f"✅ Successfully loaded and encoded face for student {name} (ID: {student_id}).")
                            
                            # Cache in Redis hash: serialize numpy array to list then JSON string
                            try:
                                r.hset(cache_key, student_id, json.dumps(encoding.tolist()))
                            except Exception as re:
                                print(f"Redis write error: {re}")
                        else:
                            print(f"⚠️ Warning: No face detected in the registered profile picture for student {name} (ID: {student_id}).")
                    else:
                        print(f"❌ Error: Failed to download profile image for {name} (Status code: {img_response.status_code})")
                            
            # Set key expiration (e.g., 2 hours) so it refreshes dynamically later
            if encodings:
                try:
                    r.expire(cache_key, 7200)
                    print(f"Cached {len(encodings)} encodings in Redis with 2-hour expiration.")
                except Exception:
                    pass
        else:
            print(f"⚠️ No students found enrolled in course {course_id}.")
    except Exception as e:
        print(f"Error loading course encodings: {e}")

    return encodings

@app.post("/recognize")
async def recognize_faces(
    course_id: str = Form(...),
    file: UploadFile = File(...)
):
    print(f"\n--- [POST /recognize] processing frame for course {course_id} ---")
    # 1. Read uploaded camera frame image bytes
    try:
        frame_bytes = await file.read()
        frame_file = io.BytesIO(frame_bytes)
        frame_image = load_image_file_upright(frame_file)
    except Exception as e:
        print(f"Failed to parse uploaded image: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid image file: {e}")

    # 2. Find all face locations and calculate their 128-d encodings in the live frame
    face_locations = face_recognition.face_locations(frame_image)
    print(f"Detected {len(face_locations)} face(s) in the camera frame.")
    if not face_locations:
        return {"detected": []}

    face_encodings = face_recognition.face_encodings(frame_image, face_locations)

    # 3. Retrieve reference encodings for this course (using Redis)
    student_encodings_dict = await get_course_student_encodings(course_id)
    if not student_encodings_dict:
        print("No student face encodings available for matching in this course.")
        return {"detected": []}

    student_ids = list(student_encodings_dict.keys())
    known_encodings = list(student_encodings_dict.values())

    detected_students = []

    for i, face_encoding in enumerate(face_encodings):
        # face_distance returns Euclidean distances: lower is closer/better match
        distances = face_recognition.face_distance(known_encodings, face_encoding)
        if len(distances) == 0:
            continue

        best_match_idx = np.argmin(distances)
        min_distance = distances[best_match_idx]
        student_id = student_ids[best_match_idx]
        
        # We can try to query student profile name locally from Redis if available, or just print ID
        print(f"Face #{i+1}: closest match is Student ID {student_id} with face distance = {min_distance:.4f}")

        # 0.6 is the standard dlib threshold. Any distance <= 0.6 is considered a match.
        if min_distance <= 0.6:
            # Convert distance score to a percentage confidence (100% is distance 0.0, 0% is distance 1.0)
            confidence = (1.0 - min_distance)
            confidence = max(0.0, min(1.0, confidence))
            print(f"🎯 Match verified! Student ID {student_id} is Present (Confidence: {confidence * 100:.1f}%)")
            detected_students.append({
                "student_id": student_id,
                "confidence": float(confidence)
            })
        else:
            print(f"❌ No match for Face #{i+1} (closest distance {min_distance:.4f} is above threshold 0.6)")

    return {"detected": detected_students}

@app.post("/clear_cache")
async def clear_cache(course_id: str = Form(...)):
    if r is not None:
        try:
            r.delete(f"course:{course_id}")
            return {"status": "success", "message": f"Cache cleared for course {course_id}"}
        except Exception as e:
            return {"status": "error", "message": str(e)}
    return {"status": "error", "message": "Redis client not initialized"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
