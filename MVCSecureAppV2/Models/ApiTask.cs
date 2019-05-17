using Newtonsoft.Json;

namespace MVCSecureAppV2.Models
{
    public class ApiTask
    {
        [JsonProperty(PropertyName = "id")]
        public string Id { get; set; }

        //[JsonProperty(PropertyName = "uri")]
        //public string Uri { get; set; }

        [JsonProperty(PropertyName = "title")]
        public string Title { get; set; }

        [JsonProperty(PropertyName = "description")]
        public string Description { get; set; }

        [JsonProperty(PropertyName = "done")]
        public bool Done { get; set; }
    }
}
