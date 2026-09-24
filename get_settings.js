const apiKey = "AIzaSyCUnsddGBcU-_ncIPcht3KfHPuvgl8cPEo";
const projectId = "reskindev-769d3";
const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/settings/global?key=${apiKey}`;

fetch(url)
  .then(res => res.json())
  .then(data => {
    if (data.fields && data.fields.youtube_url) {
      console.log("YOUTUBE_URL:", data.fields.youtube_url.stringValue);
    } else {
      console.log(data);
    }
  })
  .catch(err => console.error(err));
