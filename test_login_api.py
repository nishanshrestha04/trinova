#!/usr/bin/env python3
import requests
import json

# Test the authentication API
base_url = "http://192.168.1.116:8000/api/auth"

# Test with wrong credentials
print("Testing with wrong credentials...")
try:
    response = requests.post(
        f"{base_url}/login/",
        json={"username": "testuser", "password": "wrongpassword"},
        timeout=5
    )
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")

# Test with correct credentials
print("\nTesting with correct credentials...")
try:
    response = requests.post(
        f"{base_url}/login/",
        json={"username": "testuser", "password": "testpass123"},
        timeout=5
    )
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
