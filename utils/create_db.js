/* Simple javascript to create MongoDB databases for son-catalogue
 * This scripts needs to be run with 'installation_mongodb.sh' script
 * for a fresh MongoDB install. However, it can be run as standalone
 * with the next command from prompt if mongo is already installed:
 * sudo mongo --nodb create_db.js
 *
 * If the MongoDB is not found in localhost or is located on a different
 * port, then change "localhost:27017" accordingly from each 'connect'
 * command to the "ip_address:port" where MongoDB is installed/located.
 * Mongo Shell is required on local machine to apply script on remote a
 * remote database.
 */

db = connect("mongo:27017/son-catalogue-repository");
db.createCollection("nsd");
db.createCollection("vnfd");
db.createCollection("pd");

/* Uncomment next lines if MongoDB installation will be done in localhost, and comment lines above */
//db = connect("127.0.0.1:27017/son-catalogue-repository");
//db.createCollection("nsd");
//db.createCollection("vnfd");
//db.createCollection("pd");

