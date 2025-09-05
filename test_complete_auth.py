#!/usr/bin/env python3
"""
Test script to verify the YogAI authentication API is working correctly.
This simulates the same requests that the Flutter app makes.
"""
import requests
import json

def test_authentication_flow():
    """Test the complete authentication flow"""
    base_url = "http://192.168.18.6:8000/api/auth"
    
    print("🧘 Testing YogAI Authentication API...")
    print("=" * 50)
    
    # Test 1: Registration
    print("\n1️⃣ Testing User Registration...")
    registration_data = {
        "username": "yogauser123",
        "email": "yoga@example.com",
        "password": "securepass123",
        "first_name": "Yoga",
        "last_name": "Practitioner"
    }
    
    try:
        response = requests.post(
            f"{base_url}/register/",
            headers={"Content-Type": "application/json"},
            json=registration_data,
            timeout=10
        )
        
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 201:
            data = response.json()
            print("   ✅ Registration successful!")
            print(f"   User: {data['user']['username']} ({data['user']['email']})")
            access_token = data['access_token']
            refresh_token = data['refresh_token']
            
            # Test 2: Profile Access
            print("\n2️⃣ Testing Profile Access...")
            profile_response = requests.get(
                f"{base_url}/profile/",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {access_token}"
                },
                timeout=10
            )
            
            print(f"   Status: {profile_response.status_code}")
            if profile_response.status_code == 200:
                profile_data = profile_response.json()
                print("   ✅ Profile access successful!")
                print(f"   Profile: {profile_data['user']['first_name']} {profile_data['user']['last_name']}")
            else:
                print("   ❌ Profile access failed")
                
            # Test 3: Logout
            print("\n3️⃣ Testing Logout...")
            logout_response = requests.post(
                f"{base_url}/logout/",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {access_token}"
                },
                json={"refresh_token": refresh_token},
                timeout=10
            )
            
            print(f"   Status: {logout_response.status_code}")
            if logout_response.status_code == 200:
                print("   ✅ Logout successful!")
            else:
                print("   ❌ Logout failed")
                
        elif response.status_code == 400:
            error_data = response.json()
            if "already exists" in error_data.get('error', ''):
                print("   ⚠️  User already exists (this is normal for testing)")
                print("   Attempting login instead...")
                
                # Test Login with existing user
                login_response = requests.post(
                    f"{base_url}/login/",
                    headers={"Content-Type": "application/json"},
                    json={
                        "username": registration_data["username"],
                        "password": registration_data["password"]
                    },
                    timeout=10
                )
                
                if login_response.status_code == 200:
                    print("   ✅ Login successful!")
                    login_data = login_response.json()
                    print(f"   User: {login_data['user']['username']}")
                else:
                    print("   ❌ Login failed")
            else:
                print(f"   ❌ Registration failed: {error_data.get('error')}")
        else:
            print(f"   ❌ Registration failed with status {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("   ❌ Connection Error: Django server is not running or not accessible")
        print("   Make sure Django server is running on 0.0.0.0:8000")
        return False
    except requests.exceptions.Timeout:
        print("   ❌ Request timeout")
        return False
    except Exception as e:
        print(f"   ❌ Unexpected error: {e}")
        return False
    
    print("\n" + "=" * 50)
    print("🎉 Authentication API test completed!")
    return True

if __name__ == "__main__":
    test_authentication_flow()
