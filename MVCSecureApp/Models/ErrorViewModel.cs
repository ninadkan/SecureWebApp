using System;

namespace MVCSecureApp.Models
{
    public class ErrorViewModel
    {

        public const string ErrorAuthorizationRequired = "AuthorizationRequired";
        public const string ErrorUnexpectedError = "UnexpectedError";
        public string RequestId { get; set; }

        public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);
    }
}