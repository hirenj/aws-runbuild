FROM node:4.3.2

RUN apt-get update && apt-get install -y sqlite3 awscli curl unzip git vim less && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/hirenj/aws-runbuild /aws-runbuild
RUN chmod +x /aws-runbuild/run_buildstep.sh

CMD ["/bin/bash", "-c", "'npm install -g hirenj/node-checkversion; source /aws-runbuild/.bash; export -f build; export RUNBUILDPATH; /bin/bash'"]