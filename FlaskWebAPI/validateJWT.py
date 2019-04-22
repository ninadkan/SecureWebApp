import base64
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicNumbers
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import jwt

# Code sample inspired from 
# https://robertoprevato.github.io/Validating-JWT-Bearer-tokens-from-Azure-AD-in-Python/ 
# https://github.com/Azure-Samples/active-directory-dotnet-webapi-manual-jwt-validation/blob/master/TodoListService-ManualJwt/Global.asax.cs 


class validateJWT(object):
    """
    This class validates the bearer token that is passed. Single instance 
    of this class should be created such that it does not create the public
    key again and again. 
    """
    def __init__(self,app):
        self.valid_audiences = [app.config['ClientId']]
        self.Instance = app.config['Instance']
        self.TenantId = app.config['TenantId']
        self.Public_Key = None
        self.Issuer = None
        return 

    def ensure_bytes(self, key):
        if isinstance(key, str):
            key = key.encode('utf-8')
        return key

    def decode_value(self, val):
        decoded = base64.urlsafe_b64decode(self.ensure_bytes(val) + b'==')
        return int.from_bytes(decoded, 'big')

    def rsa_pem_from_jwk(self, jwk):
        return RSAPublicNumbers(
            n=self.decode_value(jwk['n']),
            e=self.decode_value(jwk['e'])
        ).public_key(default_backend()).public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )

    def get_kid(self,token):
        """
        extracts the 'kid' key from the header of the extracted token. 
        """
        headers = jwt.get_unverified_header(token)
        if not headers:
            raise InvalidAuthorizationToken('missing headers')
        try:
            return headers['kid']
        except KeyError:
            raise InvalidAuthorizationToken('missing kid')

    def get_jwk(self,kid, jwks):
        for jwk in jwks.get('keys'):
            if jwk.get('kid') == kid:
                return jwk
        raise InvalidAuthorizationToken('kid not recognized')

    def get_public_key(self, token, jwks):
        return self.rsa_pem_from_jwk(self.get_jwk(self.get_kid(token), jwks))

    def validate_jwt(self, jwt_to_validate):
        bRV = False

        if (self.Public_Key == None or self.Issuer == None):
            print('Getting public key for the first time... ')

            #if __debug__:
            #    import webbrowser
            #    url = 'https://jwt.ms/#id_token=' + jwt_to_validate
            #    webbrowser.open(url, new=0, autoraise=True)

            stsDiscoveryEndpoint = '{0}{1}/.well-known/openid-configuration'.format(self.Instance, self.TenantId)
            import requests
            
            r = requests.get(stsDiscoveryEndpoint)
            jsonData = r.json()
            self.Issuer = jsonData['issuer']
            jwks_uri = jsonData['jwks_uri']
            if (jwks_uri):
                
                r = requests.get(jwks_uri)
                jWks = r.json()
                self.Public_Key = self.get_public_key(jwt_to_validate, jWks)

        decoded = jwt.decode(jwt_to_validate,
                                self.Public_Key,
                                verify=True,
                                algorithms=['RS256'],
                                audience=self.valid_audiences,
                                issuer=self.Issuer)

        #print(decoded)
        bRV = True
        return bRV

    def validate_request(self, request):
        bRV = False
        authorization_header = request.headers.get('authorization')
        if (authorization_header is not None):
            token_string = authorization_header.split('Bearer ')[1]
            if (token_string is not None):
                return self.validate_jwt(token_string)
        return bRV


class InvalidAuthorizationToken(Exception):
    def __init__(self, details):
        super().__init__('Invalid authorization token: ' + details)
