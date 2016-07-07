[![Build Status](http://jenkins.sonata-nfv.eu/buildStatus/icon?job=son-catalogue-repos)](http://jenkins.sonata-nfv.eu/job/son-catalogue-repos)

# SP Catalogues and Repositories
This repository contains the development for the Service Platform catalogues and repositories. It holds the API implementation of SP catalogue and repos. Moreover, is is closely related to the [son-catalogue](https://github.com/sonata-nfv/son-catalogue) repository that holds the catalogs of the SDK as well at the [son-schema](https://github.com/sonata-nfv/son-schema) repository that holds the schema for the various descriptors, such as the VNFD and the NSD.

## Development
To contribute to the development of the SONATA editor, you may use the very same development workflow as for any other SONATA Github project. That is, you have to fork the repository and create pull requests.

### Dependencies
Ruby gems used (for more details see Gemfile):

* [Sinatra](http://www.sinatrarb.com/) - Ruby framework
* [puma](http://puma.io/) - Web server
* [json](https://github.com/flori/json) - JSON specification
* [sinatra-contrib](https://github.com/sinatra/sinatra-contrib) - Sinatra extensions
* [rake](http://rake.rubyforge.org/) - Ruby build program with capabilities similar to make
* [JSON-schema](https://github.com/ruby-json-schema/json-schema) - JSON schema validator
* [Rest-client](https://github.com/rest-client/rest-client) - HTTP and REST client
* [Yard](https://github.com/lsegal/yard) - Documentation generator tool

### Contributing
You may contribute to the editor similar to other SONATA (sub-) projects, i.e. by creating pull requests.

## Installation

After cloning the source code from the repository, you can run Catalogue-Repositories with the next command:

```sh
bundle install
```
Which will install all the gems needed to run, or if you have docker and docker-compose installed, you can run

```sh
docker-compose up
```

### Dependencies
It is recommended to use Ubuntu 14.04.4 LTS (Trusty Tahr).

This code has been run on Ruby 2.1.

A connection to a MongoDB is required, this code has been run using MongoDB version 3.2.1.

Root folder provides a script "installation_mongodb.sh" to install and set up a local MongoDB, or you can use mongoexpress to manage the remote mongo databases.

## Usage
The following shows how to start the API server:

```sh
rake start
```

or you can use docker-compose

```sh
docker-compose up
```
For testing the repositories, you can try some CRUD operations to send or retrieve records.
Method post:

```sh
curl -X POST --data-binary @test_vnfr.yaml -H "Content-type:application/x-yaml" http://localhost:4011/records/vnfr

```

Method get:
All instances

```sh
 curl http://localhost:4011/records/vnfr
```

Instance by an id:

```sh
curl -X GET http://localhost:4011/records/vnfr/9f18bc1b-b18d-483b-88da-a600e9255868
```
For testing the Catalogues, please visit the wikipage link below which contains some information to interact and test the Catalogues API.

* [Testing the code](http://wiki.sonata-nfv.eu/index.php/SONATA_Catalogues) - Inside SP Catalogue API Documentation (It currently works for SDK and SP Catalogues)

### Pushing 'sonata-demo' files to Catalogues

The Rakefile in root folder includes an specific task to fill the Catalogues with descriptor sample files from
sonata-demo package. This is specially useful when starting an empty Catalogue. It can be run with a rake task:

```sh
rake init:load_samples[<server>]

Where <server> allows two options: 'development' or 'integration' server deployment
```
An example of usage:

```sh
rake init:load_samples[integration]
```

### API Documentation

The API documentation is expected to be generated with Swagger soon. Further information can be found on SONATA's wikipages link for SONATA Catalogues:

* [SONATA Catalogues](http://wiki.sonata-nfv.eu/index.php/SONATA_Catalogues) - SONATA Catalogues on wikipages

Currently, the API is documented with yardoc and can be built with a rake task:

```sh
rake yard
```

From here you can use the yard server to browse the docs from the source root:

```sh
yard server
```

And they can be viewed from http://localhost:8808/
or you can use docker-compose and view from http://localhost:8808/

## License

The SONATA SDK Catalogue is published under Apache 2.0 license. Please see the LICENSE file for more details.

#### Useful Links

To support working and testing with the son-catalogue database it is optional to use next tools:

* [Robomongo](https://robomongo.org/download) - Robomongo 0.9.0-RC4

* [POSTMAN](https://www.getpostman.com/) - Chrome Plugin for HTTP communication

---
#### Lead Developers

The following lead developers are responsible for this repository and have admin rights. They can, for example, merge pull requests.

* Felipe Vicens (felipevicens)
* Daniel Guija (dang03)
* Santiago Rodriguez (srodriguezOPT)

#### Feedback-Channel

Please use the GitHub issues and the SONATA development mailing list sonata-dev@lists.atosresearch.eu for feedback.
