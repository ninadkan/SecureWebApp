using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;

namespace MVCSecureAppV2.Services
{
    public class PythonWebAPIClientFactory
    {
        public static PythonWebAPIClient GetAuthenticatedPythonWebClient(Func<Task<string>> acquireAccessToken,
                                                                                 string baseUrl)
        {
            return new PythonWebAPIClient(baseUrl, new CustomAuthenticationProvider(acquireAccessToken));
        }

        class CustomAuthenticationProvider : IAuthenticationProvider
        {
            public CustomAuthenticationProvider(Func<Task<string>> acquireTokenCallback)
            {
                acquireAccessToken = acquireTokenCallback;
            }

            private Func<Task<string>> acquireAccessToken;

            public async Task AuthenticateRequestAsync(HttpRequestMessage request)
            {
                string accessToken = await acquireAccessToken.Invoke();

                // Append the access token to the request.
                request.Headers.Authorization = new AuthenticationHeaderValue(
                    Infrastructure.Constants.BearerAuthorizationScheme, accessToken);
            }
        }
    }
}
