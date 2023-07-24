Kafka REST Dev
--------------

This repo contains docker-compose with Kakfa and Kafka Rest proxy for local development.

Services:
- Kafka (Two brokers)
- [Kafka Rest](https://docs.confluent.io/platform/current/kafka-rest/index.html)
- RA
- [Schema Registry](https://docs.confluent.io/platform/current/schema-registry/develop/api.html)
- Schema Registry UI
- [CMAK](https://github.com/yahoo/CMAK)
- [AKHQ](https://github.com/tchiotludo/akhq)


Ports:
- :19093 kafka broker 1
- :29093 kafka broker 1
- nginx
  - :8082 Kafka Rest(with RA)
  - :8081 Schema Registry(with RA) ReadOnly
- [:8000](http://127.0.0.1:8000) Schema Registry UI
- [:8080](http://127.0.0.1:8080) AKHQ
- [:9000](http://127.0.0.1:9000) CMAK


## Start and stop

Start:
```bash
HOSTNAME=$(hostname) docker-compose up -d
```

or (better) set host name to .env file
```bash
echo "HOSTNAME=$(hostname)" >> .env
docker-compose up -d
```

or only kafka
```
docker-compose up -d broker1 broker2 zookeeper ksm cmak akhq
```

Stop(and clean all data):
```bash
HOSTNAME=$(hostname) docker-compose down -v
```


## KCat

### Get broker metadata

```
kcat -X security.protocol=ssl \
     -X ssl.ca.location=secrets/snakeoil-ca-1.crt \
     -X ssl.certificate.location=secrets/kafkacat.pem \
     -X ssl.key.location=secrets/kafkacat.key \
     -X ssl.key.password=changeme \
     -L -b localhost:19093 -J
```

Output (example):
```
{"originating_broker":{"id":-1,"name":"ssl://localhost:19093/bootstrap"},"query":{"topic":"*"},"controllerid":1,"brokers":[{"id":2,"name":"MacBook-Pro-Ilya.local:29093"},{"id":1,"name":"MacBook-Pro-Ilya.local:19093"}],"topics":[]}
```

### Produce a message

```
echo '123123' | kcat -X security.protocol=ssl \
	-X ssl.ca.location=secrets/snakeoil-ca-1.crt \
        -X ssl.certificate.location=secrets/kafkacat.pem \
        -X ssl.key.location=secrets/kafkacat.key \
        -X ssl.key.password=changeme \
        -b localhost:19093 -P -t  999-9.example.db.name.0
```

## Kafka REST

Kafka REST user is defined in `nginx/kafka_htpasswd` (password can be safity changed):
* User: kafka_local_dev Password: kafka_$tr0ng_pwd

Cluster name: `999-9`.
All topics name must start with `999-9`(Please see naming convention).

### Kafka REST send message example:

```bash
curl -v -u 'kafka_local_dev:kafka_$tr0ng_pwd' \
  -X POST -H "Content-Type: application/vnd.kafka.avro.v2+json" \
  -d @examples/999-9.example.db.test1.0-body.txt \
  http://localhost:8082/topics/999-9.example.db.test1.0
```

Responce:
```bash
{"offsets":[{"partition":0,"offset":0,"error_code":null,"error":null}],"key_schema_id":1,"value_schema_id":2}
```

You can check data in the AKHQ.

## Regenerate certs

1. Stop all services
2. Clean `secrets` directory(`rm -f secrets/*`)
3. Generate new secrets(`./create-certs.sh`)
4. Start services from docker-compose

## OPA

Gen policy:
 docker run -it --rm -v $(pwd)/policy:/policy  openpolicyagent/opa:0.54.0-rootless build /policy/base.rego -o /policy/bundle.tar.gz


### TODO:
- https://traefik.io/blog/traefik-2-tls-101-23b4fbee81f1/
- Сервис генерации бутрап схем и валидации
- opa: https://repo1.maven.org/maven2/org/openpolicyagent/kafka/opa-authorizer/
