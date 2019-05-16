using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace MVCSecureAppV2.Services
{
    public class PythonWebAPIClient
    {
        IAuthenticationProvider _authProvider;
        private static string _commonURL = null;
        public PythonWebAPIClient(string PythonWebAPIURL, IAuthenticationProvider authProvider)
        {
            _commonURL = PythonWebAPIURL;
            _authProvider = authProvider;
        }
    }
}
