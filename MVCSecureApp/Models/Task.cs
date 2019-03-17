using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace MVCSecureApp.Models
{
    public class Task
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
