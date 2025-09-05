#!/usr/bin/env python
import requests
import json

def test_api():
    base_url = "http://127.0.0.1:8000/api/auth"
    
    # Test registration
    registration_data = {
        "username": "testuser123",
        "email": "test123@example.com",
        "password": "testpass123",
        "first_name": "Test",
        "last_name": "User"
    }
    
    try:
        print("Testing registration endpoint...")
        response = requests.post(
            f"{base_url}/register/",
            headers={"Content-Type": "application/json"},
            json=registration_data,
            timeout=10
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 201:
            print("✅ Registration successful!")
            return response.json()
        else:
            print("❌ Registration failed")
            return None
            
    except requests.exceptions.ConnectionError:
        print("❌ Connection refused - Django server is not running")
        return None
    except requests.exceptions.Timeout:
        print("❌ Request timeout")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

if __name__ == "__main__":
    test_api()
