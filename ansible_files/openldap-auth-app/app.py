from ldap3 import Server, Connection, ALL
from flask import Flask, request, jsonify

app = Flask(__name__)

LDAP_SERVER = 'ldap://openldap:389'  # LDAP server address
LDAP_BASE_DN = 'dc=myorganization,dc=com'  # Base DN for your LDAP directory

def authenticate(username, password):
    # Define the DN based on the user's group and base DN
    user_dn = f"cn={username},cn=developers,ou=Groups,{LDAP_BASE_DN}"

    # Connect to the LDAP server
    server = Server(LDAP_SERVER, get_info=ALL)
    conn = Connection(server, user=user_dn, password=password)

    # Attempt to bind (authenticate)
    if conn.bind():
        conn.unbind()  # Disconnect once authenticated
        return True
    else:
        conn.unbind()
        return False

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"message": "Username and password are required"}), 400

    if authenticate(username, password):
        return jsonify({"message": "Authentication successful"}), 200
    else:
        return jsonify({"message": "Authentication failed"}), 401

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)