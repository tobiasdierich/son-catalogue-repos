
# SP Catalogues and Repositories [![Build Status](http://jenkins.sonata-nfv.eu/buildStatus/icon?job=son-catalogue-repos)](http://jenkins.sonata-nfv.eu/job/son-catalogue-repos)
This repository contains the development for the Service Platform catalogues and repositories. It holds the API implementation of SP catalogue and repos. Moreover, is is closely related to the [son-catalogue](https://github.com/sonata-nfv/son-catalogue) repository that holds the catalogs of the SDK as well at the [son-schema](https://github.com/sonata-nfv/son-schema) repository that holds the schema for the various descriptors, such as the VNFD and the NSD.

### Requirements

This code has been run on Ruby 2.1.

### Gems used

* [Sinatra](http://www.sinatrarb.com/) - Ruby framework
* [json](https://github.com/flori/json) - JSON specification
* [sinatra-contrib](https://github.com/sinatra/sinatra-contrib) - Sinatra extensions
* [JSON-schema](https://github.com/ruby-json-schema/json-schema) - JSON schema validator
* [Rest-client](https://github.com/rest-client/rest-client) - HTTP and REST client
* [Yard](https://github.com/lsegal/yard) - Documentation generator tool

### Installation

After you cloned the source from the repository, you can run

```sh
bundle install

```

Which will install all the gems.


or, if you have docker and docker-compose installed, you can run

```sh
docker-compose up

```

### Tests

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

You can use mongoexpress to manage the mongo databases.

### Pushing 'sonata-demo' files to Catalogues

The Rakefile in root folder includes an specific task to fill the Catalogues with descriptor sample files from
sonata-demo package. This is specially useful when starting an empty Catalogue. It can be run with a rake task:

```sh
rake init:load_samples
```

### API Documentation

The API is documented with yardoc and can be built with a rake task:

```sh
rake yard
```
from here you can use the yard server to browse the docs from the source root:

```sh
yard server
```

and they can be viewed from http://localhost:8808/


or you can use docker-compose and view from http://localhost:8808/

### Run Server

The following shows how to start the API server:

```sh
rake start
```

or you can use docker-compose

```sh
docker-compose up
```

---
#### Lead Developers

The following lead developers are responsible for this repository and have admin rights. They can, for example, merge pull requests.

- Felipe Vicens (felipevicens)
- Daniel Guija (dang03)
