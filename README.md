[![Build Status](http://jenkins.sonata-nfv.eu/buildStatus/icon?job=son-catalogue-repos)](http://jenkins.sonata-nfv.eu/job/son-catalogue-repos)

# SP Catalogues and Repositories
This repository contains the development for the Service Platform catalogues and repositories. It holds the API implementation of SP catalogue and repos. Moreover, is is closely related to the [son-catalogue](https://github.com/sonata-nfv/son-catalogue) repository that holds the catalogs of the SDK as well at the [son-schema](https://github.com/sonata-nfv/son-schema) repository that holds the schema for the various descriptors, such as the VNFD and the NSD.

## Development
To contribute to the development of the SONATA editor, you may use the very same development workflow as for any other SONATA Github project. That is, you have to fork the repository and create pull requests.

### Dependencies
It is recommended to use Ubuntu 14.04.4 LTS (Trusty Tahr).

This code has been run on Ruby 2.1.

A connection to a MongoDB is required, this code has been run using MongoDB version 3.2.1.

Root folder provides a script "installation_mongodb.sh" to install and set up a local MongoDB, or you can use mongoexpress to manage the remote mongo databases.

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

## Usage
The following shows how to start the API server for the Catalogues-Repositories:

```sh
rake start
```

or you can use docker-compose

```sh
docker-compose up
```

The Repositories' API allows the use of CRUD operations to send or retrieve records.
The available records include services records (NSR) and functions records (VNFR).
For testing the Repositories, you can use 'curl' tool to send a request to the API. It is required to set the HTTP header 'Content-type' field to 'application/json' or 'application/x-yaml' according to your desired format.
Remember to set the IP address and port accordingly.

Method GET:

To receive all instances you can use

```sh
 curl http://localhost:4011/records/nsr
```
```sh
 curl http://localhost:4011/records/vnfr
```

To receive an instance by its ID:

```sh
curl -X GET http://localhost:4011/records/nsr/9f18bc1b-b18d-483b-88da-a600e9255868
```
```sh
curl -X GET http://localhost:4011/records/vnfr/9f18bc1b-b18d-483b-88da-a600e9255016
```

Method POST:

To send a record instance

```sh
curl -X POST --data-binary @test_nsr.yaml -H "Content-type:application/x-yaml" http://localhost:4011/records/nsr
```
```sh
curl -X POST --data-binary @test_vnfr.yaml -H "Content-type:application/x-yaml" http://localhost:4011/records/vnfr
```

The Catalogues' API allows the use of CRUD operations to send, retrieve, update and delete descriptors.
The available descriptors include services (NSD), functions (VNFD) and packages (PD) descriptors.
The Catalogues also support storage for SONATA packages, the binary files that contain the descriptors.
For testing the Catalogues, you can use 'curl' tool to send a request to the API. It is required to set the HTTP header 'Content-type' field to 'application/json' or 'application/x-yaml' according to your desired format.

Method GET:

To receive all descriptors you can use

```sh
curl http://localhost:4011/catalogues/network-services
```
```sh
curl http://localhost:4011/catalogues/vnfs
```
```sh
curl http://localhost:4011/catalogues/packages
```

To receive a descriptor by its ID:

```sh
curl http://localhost:4011/catalogues/network-services/9f18bc1b-b18d-483b-88da-a600e9255016
```
```sh
curl http://localhost:4011/catalogues/vnfs/9f18bc1b-b18d-483b-88da-a600e9255017
```
```sh
curl http://localhost:4011/catalogues/packages/9f18bc1b-b18d-483b-88da-a600e9255018
```

Method POST:

To send a descriptor

```sh
curl -X POST --data-binary @nsd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/network-services
```
```sh
curl -X POST --data-binary @vnfd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/vnfs
```
```sh
curl -X POST --data-binary @pd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/packages
```

Method PUT:

To update a descriptor is similar to the POST method, but it is required that a older version of the descriptor is stored in the Catalogues

```sh
curl -X POST --data-binary @nsd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/network-services
```
```sh
curl -X POST --data-binary @vnfd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/vnfs
```
```sh
curl -X POST --data-binary @pd_sample.yaml -H "Content-type:application/x-yaml" http://localhost:4011/catalogues/packages
```

Method DELETE:

To remove a descriptor by its ID

```sh
curl -X DELETE http://localhost:4011/catalogues/network-services/9f18bc1b-b18d-483b-88da-a600e9255016
```
```sh
curl -X DELETE http://localhost:4011/catalogues/vnfs/9f18bc1b-b18d-483b-88da-a600e9255017
```
```sh
curl -X DELETE http://localhost:4011/catalogues/packages/9f18bc1b-b18d-483b-88da-a600e9255018
```

The API for SONATA packages works very similar to the API for the descriptors or records.

Method GET:

To receive a list of stored packages

```sh
curl http://localhost:4011/catalogues/son-packages
```

To receive a package file

```sh
curl http://localhost:4011/catalogues/son-packages/9f18bc1b-b18d-483b-88da-a600e9255000
```
Method POST:

To send a package file

HTTP header 'Content-Type' must be set to 'application/zip'

HTTP header 'Content-Disposition' must be set to 'attachment; filename=```name_of_the_package```'

```sh
curl -X POST -H "Content-Type: application/zip" -H "Content-Disposition: attachment; filename=sonata_example.son" -F "@sonata-demo.son" "http://0.0.0.0:4011/catalogues/son-packages"
```

Method DELETE:

To remove a package file by its ID

```sh
curl -X DELETE http://localhost:4011/catalogues/son-packages/9f18bc1b-b18d-483b-88da-a600e9255000
```

For more information about usage of Catalogues, please visit the wikipage link below which contains some information to interact and test the Catalogues API.

* [Testing the code](http://wiki.sonata-nfv.eu/index.php/SONATA_Catalogues) - Inside SP Catalogue API Documentation (It currently works for SDK and SP Catalogues)

### Pushing 'sonata-demo' files to Catalogues

The Rakefile in root folder includes an specific task to fill the Catalogues with descriptor sample files from
sonata-demo package. This is specially useful when starting an empty Catalogue. It can be run with a rake task:

```sh
rake init:load_samples[<server>]

Where <server> allows two options: 'development' or sh'integration' server deployment
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

## Useful Links

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
