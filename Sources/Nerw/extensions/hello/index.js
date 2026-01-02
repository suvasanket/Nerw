async function main(query) {
    nerw.log("Hello from JS! Query: " + query);

    return [
       {
         title: "Hello " + (query || "World"),
         subtitle: "From JavaScript Extension",
         icon: "hand.wave",
         action: "copy"
       },
       {
         title: "Google",
         subtitle: "Search Google",
         icon: "globe",
         action: "https://google.com"
       }
    ];
}
