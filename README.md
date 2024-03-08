# RECRUTAMENTO - ANALISTA DE INFRAESTRUTURA

As instruções a seguir contém a minha solução para a atividade de recrutamento da ESIG. A atividade consiste nas seguintes instruções:

1. Baixe o arquivo WAR do Jenkins mais recente do site oficial ou de outra fonte
confiável.
2. Configure um servidor de aplicação local, como JBoss ou Tomcat.
3. Implante o arquivo WAR do Jenkins no servidor configurado.
4. Inicie o servidor de aplicação e verifique se o Jenkins está sendo executado
corretamente.
5. Acesse a interface web 

Também serão considerados como extras:

- Monte uma apresentação na ferramenta de apresentação de sua preferência;
- Você terá até 20 minutos para apresentar
- Além do desafio, pode ser apresentado um outro projeto que utilize Jboss.
Será contado como extra.
- Caso entenda como importante, esse ambiente pode ser monitorado.
Sugestão: usar prometheus e grafana em contêiner para isso pode usar as
```
    imagens:
    - Prometheus:
        - imagem:prom/prometheus:latest
    - Grafana:
        - image: grafana/grafana:latest
```

## Configuração do Servidor de aplicação local (JBOSS - Wildfly) (Debian)


1. Instalar a JDK mais recente:

```
sudo apt update
sudo apt install default-jdk
java --version
```

2. Baixe o release mais recente do Wildfly:

```
wget https://github.com/wildfly/wildfly/releases/download/26.0.0.Final/wildfly-26.0.0.Final.tar.gz
```

3. Extraia os arquivos:

```
tar -xf wildfly-*.Final.tar.gz
sudo mv wildfly-*Final /opt/wildlfy
```

4. Crie o usuário e o grupo wildfly:

```
sudo groupadd -r wildfly
sudo useradd -r -g wildfly -d /opt/wildfly -s /sbin/nologin wildfly
```

5. Mude as permissões do diretório de wildfly:

```
sudo chown -RH wildfly:wildfly /opt/wildfly
```

6. Configure o Wildfly:

```
sudo mkdir -p /etc/wildfly
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/wildfly.conf /etc/wildfly/
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/wildfly.service /etc/systemd/system/
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/launch.sh /opt/wildfly/bin/
```

7. Autorize a execução dos scripts do wildfly:

```
sudo chmod +x /opt/wildfly/bin/*.sh
```

9. Inicie o daemon do wildfly:

```
sudo systemctl daemon-reload
sudo systemctl enable --now wildfly
systemctl status wildfly
```

Se o procedimento foi executado corretamente o resultado do `systemctl status` deve ser:

```
● wildfly.service - The WildFly Application Server
     Loaded: loaded (/etc/systemd/system/wildfly.service; disabled; preset: enabled)
     Active: active (running) since Fri 2024-03-08 06:47:27 -03; 5s ago
   Main PID: 113126 (launch.sh)
      Tasks: 84 (limit: 19020)
     Memory: 271.8M (peak: 284.7M)
        CPU: 7.692s
     CGroup: /system.slice/wildfly.service
             ├─113126 /bin/bash /opt/wildfly/bin/launch.sh standalone standalone.xml 0.0.0.0
             ├─113127 /bin/sh /opt/wildfly/bin/standalone.sh -c standalone.xml -b 0.0.0.0
             └─113279 java "-D[Standalone]" "-Djdk.serialFilter=maxbytes=10485760;maxdepth=128;maxarray=100000;maxrefs=300000" -Xms64m -Xmx512m -XX:MetaspaceSize=96M -XX:MaxMet>

Mar 08 06:47:27 desktop systemd[1]: Started wildfly.service - The WildFly Application Server.
```

## Configurando o Jenkins

1. Baixe o arquivo jenkins.war:

```
wget https://get.jenkins.io/war-stable/2.440.1/jenkins.war
```

2. Copie o arquivo para /opt/wildfly/standalone/deployments:

```
sudo cp jenkins.war /opt/wildfly/standalone/deployments
```

3. Reinicie o deamon do wildfly:

```
sudo systemctl restart wildfly
```

## Executando os processe automatizado

Com os scripts ansible você pode executar os processos anteriores automaticamente. 

1. Crie o arquivo de inventário do ansible ´inventory.ini´, como esse exemplo:

```
[local]
localhost ansible_connection=local

[local:vars]
user=<usuário>
wildfly_version=31.0.1.Final
jenkins_version=2.440.1 
```

2. Execute o script de instalação e configuração do wildfly:

```
ansible-playbook -i inventory.ini setup_wildfly.yml --ask-become-pass
```

3. Execute o script de instalação e configuração do jenkins:

```
ansible-playbook -i inventory.ini setup_jenkins.yml --ask-become-pass
```

## Configurando statck de monitoramento (Grafana/Prometheus)

Instanciaremos o grafana e o prometheus utilizando docker-compose.

1. Crie o arquivo ´docker-compose.yml´:

```yml
version: '3'

volumes:
    prometheus_data: {}
    grafana_data: {}

services:

  grafana:
    image: grafana/grafana-enterprise
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
     - '3000:3000'

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus-config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-config/jenkins-token:/etc/prometheus/jenkins-token
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
     - '9090:9090'
```

2. Acesse o jenkins em `http://localhost:8080/jenkins`, e utilize a senha de admin inicial, disponível em ´/opt/wildfly/.jenkins/secrets/initialAdminPassword´;

3. Crie o usuário de administração utilizando uma boa senha e instale os plugins padrões;

4. Acesse as configurações de usuário e acesse **Configure** e gere um API Token, copie o token e salve em um arquivo, por exemplo `prometheus-config/jekins-token`;

5. Acesse a opção **Manage Jenkins > Plugins** e instale o plugin "Prometheus metrics plugin";

6. Com isso instancie o grafana e o prometheus:

```
docker compose up -d
```

7. Você pode acessar o prometheus em `http://localhost:9090/` e verifica em **Status>Targets** se o endpoint de metrics está UP;

8. Acesse o granafa em `http://localhost:3000/` e adicione a dashbord 9964 configurando o datasource do prometheus com `http://prometheus:9090`.


