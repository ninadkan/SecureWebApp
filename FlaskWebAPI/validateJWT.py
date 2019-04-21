
#http://localhost:44321/api/todolist
#Webuser@ninadkanthihotmail054.onmicrosoft.com

#eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ilg1ZVhrNHh5b2pORnVtMWtsMll0djhkbE5QNC1jNTdkTzZRR1RWQndhTmsifQ.eyJleHAiOjE1NTMxMTU3NjYsIm5iZiI6MTU1MzExMjE2NiwidmVyIjoiMS4wIiwiaXNzIjoiaHR0cHM6Ly9uaW5hZGthbnRoaS5iMmNsb2dpbi5jb20vZTNhYzBmMWMtNTI1Ny00M2I4LTk2NTgtZDlkODVmMjk1OTQyL3YyLjAvIiwic3ViIjoiNTFlNjliMDItNzJmMS00ZTI5LTk4MmMtMzhmNWI4Zjk2ODJhIiwiYXVkIjoiNjJjZGEyZDUtNjU1Mi00MzhmLWFmZWItNzFmNzM1YjRjMTUxIiwibm9uY2UiOiJkZWZhdWx0Tm9uY2UiLCJpYXQiOjE1NTMxMTIxNjYsImF1dGhfdGltZSI6MTU1MzExMjE2Niwib2lkIjoiNTFlNjliMDItNzJmMS00ZTI5LTk4MmMtMzhmNWI4Zjk2ODJhIiwiZW1haWxzIjpbIm5pbmFkLmthbnRoaUBvdXRsb29rLmNvbSJdLCJuZXdVc2VyIjp0cnVlLCJnaXZlbl9uYW1lIjoiTmluYWQiLCJmYW1pbHlfbmFtZSI6IkthbnRoaSIsInRmcCI6IkIyQ18xX3NpZ25pbl9zaWdudXAifQ.KxQj4SATBOb9HlS53RIm9XwAhuPcpFy6fxZ3qeJ7u1h9AJC80DXWo5bZjkpcKCbycRJYS_KpIDHMD_y7gSwG1nd5ZHoCJUYBybHv8xUm_DVpyfwwiDHM8XSYuAA5RnMnPvEgw55EYN1Sg-jjTfBE8-eHG5YUQ0_mWxq8ziOp4V7FOVPUXA0sa8jJdSFVtBngFbkVr58fWCcwqRHH3xhcfaBuFAY8mLZcJXlCq5rW04s37IugipYDzJVMWQxVd-aLSLkjwCAecGM216ZqeR6wZobEAOUgoJXPJNdzm9Fh921_8rdWojdAxoY8awTDtLxyYX0xa46CidRBFAs60KAbGw

#https://login.microsoftonline.com/d3f823f0-2418-4808-96f0-4eaba79f24ae/.well-known/openid-configuration


#https://login.microsoftonline.com/d3f823f0-2418-4808-96f0-4eaba79f24ae/discovery/keys?p=B2C_1_signin_signup

# The template is coming from this -
# https://github.com/Azure-Samples/active-directory-dotnet-webapi-manual-jwt-validation



import base64
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization


def ensure_bytes(key):
    if isinstance(key, str):
        key = key.encode('utf-8')
    return key


def decode_value(val):
    decoded = base64.urlsafe_b64decode(ensure_bytes(val) + b'==')
    return int.from_bytes(decoded, 'big')


def rsa_pem_from_jwk(jwk):
    return RSAPublicNumbers(
        n=decode_value(jwk['n']),
        e=decode_value(jwk['e'])
    ).public_key(default_backend()).public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )


import jwt
#from jwksutils import rsa_pem_from_jwk  # <-- this module contains the piece of code described previously

# obtain jwks as you wish: configuration file, HTTP GET request to the endpoint returning them;
jwks = {
    "keys": [
        {
            "kid": "X5eXk4xyojNFum1kl2Ytv8dlNP4-c57dO6QGTVBwaNk",
            "nbf": 1493763266,
            "use": "sig",
            "kty": "RSA",
            "e": "AQAB",
            "n": "tVKUtcx_n9rt5afY_2WFNvU6PlFMggCatsZ3l4RjKxH0jgdLq6CScb0P3ZGXYbPzXvmmLiWZizpb-h0qup5jznOvOr-Dhw9908584BSgC83YacjWNqEK3urxhyE2jWjwRm2N95WGgb5mzE5XmZIvkvyXnn7X8dvgFPF5QwIngGsDG8LyHuJWlaDhr_EPLMW4wHvH0zZCuRMARIJmmqiMy3VD4ftq4nS5s8vJL0pVSrkuNojtokp84AtkADCDU_BUhrc2sIgfnvZ03koCQRoZmWiHu86SuJZYkDFstVTVSR0hiXudFlfQ2rOhPlpObmku68lXw-7V-P7jwrQRFfQVXw"
        }
    ]
}

# configuration, these can be seen in valid JWTs from Azure B2C:
valid_audiences = ['62cda2d5-6552-438f-afeb-71f735b4c151'] # id of the application prepared previously
issuer = 'https://ninadkanthi.b2clogin.com/e3ac0f1c-5257-43b8-9658-d9d85f295942/v2.0/' # iss , check the token in the //jwt.ms


class InvalidAuthorizationToken(Exception):
    def __init__(self, details):
        super().__init__('Invalid authorization token: ' + details)


def get_kid(token):
    headers = jwt.get_unverified_header(token)
    if not headers:
        raise InvalidAuthorizationToken('missing headers')
    try:
        return headers['kid']
    except KeyError:
        raise InvalidAuthorizationToken('missing kid')


def get_jwk(kid):
    for jwk in jwks.get('keys'):
        if jwk.get('kid') == kid:
            return jwk
    raise InvalidAuthorizationToken('kid not recognized')


def get_public_key(token):
    return rsa_pem_from_jwk(get_jwk(get_kid(token)))


def validate_jwt(jwt_to_validate):
    public_key = get_public_key(jwt_to_validate)

    decoded = jwt.decode(jwt_to_validate,
                         public_key,
                         verify=True,
                         algorithms=['RS256'],
                         audience=valid_audiences,
                         issuer=issuer)

    # do what you wish with decoded token:
    # if we get here, the JWT is validated
    print(decoded)


def Authenticate():
    bool rv = False
    msg = ""
    import sys
    import traceback

    # if len(sys.argv) < 2:
    #     print('Please provide a JWT as script argument')
    #     return
    
    # jwt = sys.argv[1]
    # f = open("jwtToken.txt", "r")
    # jwt = f.read()

    authorization_header = request.headers.get('authorization')
    jwt = authorization_header.split('Bearer ')[1]

    if not jwt:
        #print('Please pass a valid JWT')
        rv = False

    try:
        validate_jwt(jwt)
    except Exception as ex:
        traceback.print_exc()
        #print('The JWT is not valid!')
    else:
        #print('The JWT is valid!')
        rv = True
    return rv


if __name__ == '__main__':
    main()


