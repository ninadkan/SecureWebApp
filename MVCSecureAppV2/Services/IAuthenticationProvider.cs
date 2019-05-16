using System.Threading.Tasks;
using System.Net.Http;

namespace MVCSecureAppV2.Services
{
        public interface IAuthenticationProvider
        {
            //
            // Summary:
            //     Authenticates the specified request message.
            //
            // Parameters:
            //   request:
            //     The System.Net.Http.HttpRequestMessage to authenticate.
            //
            // Returns:
            //     The task to await.
            Task AuthenticateRequestAsync(HttpRequestMessage request);
        }
}
