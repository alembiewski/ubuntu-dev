TARGET_REPO := $(GOPATH)/src/github.com/mesosphere/dkp-insights
TARGET_REPO_CB := $(GOPATH)/src/github.com/mesosphere/chatbot
TARGET_REPO_AA := $(GOPATH)/src/github.com/mesosphere/apiauthorizer

TERRAFORM_OPTS := -var owner=$(shell whoami) -auto-approve
EC2_INSTANCE_USER := ubuntu

ifneq ("$(wildcard $(CURDIR)/inventory)","")
EC2_INSTANCE_HOST := $(strip $(shell cat inventory | grep -E "(.*)amazonaws\.com"))
EC2_SSH_KEY := $(shell cat inventory | grep -E ".*\.pem" | cut -d "=" -f 2)
endif

SSH_OPTS := -i $(EC2_SSH_KEY) -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30

RSYNC_OPTS := -rav --delete --exclude .idea --exclude .local --exclude artifacts --exclude pkg/generated -e "ssh $(SSH_OPTS)" $(TARGET_REPO) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST):~/go/src/github.com/mesosphere
RSYNC_OPTS_CB := -rav --delete --exclude .idea --exclude .local --exclude artifacts --exclude pkg/generated -e "ssh $(SSH_OPTS)" $(TARGET_REPO_CB) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST):~/go/src/github.com/mesosphere
RSYNC_OPTS_AA := -rav --delete --exclude .idea --exclude .local --exclude artifacts --exclude pkg/generated -e "ssh $(SSH_OPTS)" $(TARGET_REPO_AA) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST):~/go/src/github.com/mesosphere
SSH_TUNNEL_PORT := 1337

PORT_FORWARD ?= 8090

# Start one-way synchronization of the $(TARGET_REPO) to the remote host
.PHONY: sync-repo
sync-repo:
	# Perform initial sync
	rsync $(RSYNC_OPTS)
	# Watch for changes and sync
	fswatch --one-per-batch --recursive --latency 1 $(TARGET_REPO) | xargs -I{} rsync $(RSYNC_OPTS)

# Start one-way synchronization of the $(TARGET_REPO_CB) to the remote host
.PHONY: sync-chatbot-repo
sync-chatbot-repo:
	# Perform initial sync
	rsync $(RSYNC_OPTS_CB)
	# Watch for changes and sync
	fswatch --one-per-batch --recursive --latency 1 $(TARGET_REPO_CB) | xargs -I{} rsync $(RSYNC_OPTS_CB)

# Start one-way synchronization of the $(TARGET_REPO_AA) to the remote host
.PHONY: sync-apiauthorizer-repo
sync-apiauthorizer-repo:
	# Perform initial sync
	rsync $(RSYNC_OPTS_AA)
	# Watch for changes and sync
	fswatch --one-per-batch --recursive --latency 1 $(TARGET_REPO_AA) | xargs -I{} rsync $(RSYNC_OPTS_AA)

# Create SSH tunnel to the remote instance
.PHONY: tunnel
tunnel:
	ssh $(SSH_OPTS) -D $(SSH_TUNNEL_PORT) -f -C -q -N $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST)

.PHONY: dashboard
dashboard: tunnel
dashboard:
	@echo Obtaining DKP credentials...
	@ssh $(SSH_OPTS) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST) "kubectl -n kommander get secret dkp-credentials \
		-o go-template='{{ \"\n\"}}Username: {{.data.username|base64decode}}{{ \"\n\"}}Password: {{.data.password|base64decode}}{{ \"\n\"}}'"
	@echo "---------------------------------------------------"
	@echo Launching Kommander Dashboard...
	@open $(shell ssh $(SSH_OPTS) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST) "kubectl -n kommander get svc kommander-traefik \
		-o go-template='https://{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}/dkp/kommander/dashboard{{ \"\n\"}}'")

# Connect to the remote instance
.PHONY: connect
connect:
	ssh $(SSH_OPTS) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST)

# Create an EC2 instance with Terraform
.PHONY: create
create:
	terraform init
	terraform apply $(TERRAFORM_OPTS)

# Destroy an EC2 instance
.PHONY: destroy
destroy:
	terraform destroy $(TERRAFORM_OPTS)

.PHONY: clean
clean:
	rm -rf .terraform* *.pem terraform.tfstate*

.PHONY: port-forward
port-forward:
	ssh $(SSH_OPTS) -N -L $(PORT_FORWARD):localhost:$(PORT_FORWARD) $(EC2_INSTANCE_USER)@$(EC2_INSTANCE_HOST)