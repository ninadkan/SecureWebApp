namespace MVCSecureApp.Models
{
    public class ErrorViewModel
    {
        public const string ErrorAuthorizationRequired = "AuthorizationRequired";
        public const string ErrorUnexpectedError = "UnexpectedError";
        public const string PromptConsentCookie = "PromptConsent";
        public string RequestId { get; set; }
        public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);

        public string ErrorHeader { get; set; }
        public bool ShowErrorHeader => !string.IsNullOrEmpty(ErrorHeader);

        public string ErrorDescription { get; set; }
        public bool ShowErrorDescription => !string.IsNullOrEmpty(ErrorDescription);
    }
}