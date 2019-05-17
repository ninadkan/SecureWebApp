using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace MVCSecureAppV2.Infrastructure
{
    public class Constants
    {
        public const string ScopeUserRead = "User.Read";
        public const string ScopeUserImpersonation = "user_impersonation";
        public const string BearerAuthorizationScheme = "Bearer";
    }
}
