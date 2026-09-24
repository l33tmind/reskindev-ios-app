const admin = require('./functions/node_modules/firebase-admin');
const serviceAccount = require('./functions/reskindev-769d3-firebase-adminsdk-r735l-950e300fc5.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();
db.collection('services').get().then(snap => {
  console.log("Found " + snap.docs.length + " services");
  snap.docs.forEach(doc => {
    console.log(doc.id, doc.data().title, doc.data().status);
  });
}).catch(console.error);
