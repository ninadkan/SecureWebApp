using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MVCSecureAppV2.Services
{
    public static class Bootstrapper
    {
        public static void AddPythonWebAPIService(this IServiceCollection services, IConfiguration configuration)
        {
            services.Configure<PythonWebAPIOptions>(configuration);
        }
    }
}
