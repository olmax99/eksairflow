define message1
 Environment variable BASE_IP is required. Not set.
 		Use following command:
        "$$ my_ip=`curl ipinfo.io | jq .ip`;eval my_ip=$${my_ip[i]};my_ip="$$my_ip/32"; export BASE_IP=$$my_ip"

endef

define get_certs_bucket
$(shell aws cloudformation describe-stacks \
	--stack-name '$(1)' \
	--query "Stacks[0].Outputs[?OutputKey=='$(2)'].OutputValue" \
	--output text)

endef

ifndef BASE_IP
export message1
$(error $(message1))
endif

SHELL := /bin/bash

# CloudFormation master
CURRENT_LOCAL_IP = $(BASE_IP)
CFN_TEMPLATES_BUCKET := kubeairflow-cloudformation-eu-central-1
AWS_REGION := eu-central-1
PROJECT_NAME := kubeairflow-staging
VPN_KEY_NAME := eksairflow-staging-bastion
VPN_CERTS_BUCKET := $(call get_certs_bucket,$(PROJECT_NAME),CertsBucket)

# -------------------- Run tests---------------------------------------------

lint:
	cfn-lint templates/cluster/*.template
	cfn-lint templates/services/*.template

test:
	taskcat -c ./ci/taskcat.yaml

sync:
	aws s3 sync --exclude '.*' --acl public-read . $(BUCKET)

# -------------------- Launch Cfn Master-------------------------------------

templates:
		aws s3 cp --recursive cloudformation/staging/cluster s3://${PROJECT_NAME}-${AWS_REGION}/stagingtemplates/ && \
        aws s3 cp --recursive cloudformation/staging/services s3://${PROJECT_NAME}-${AWS_REGION}/stagingtemplates/ && \
        aws s3 cp --recursive cloudformation/staging/ci s3://${PROJECT_NAME}-${AWS_REGION}/stagingtemplates/

cluster: templates
		aws cloudformation --region ${AWS_REGION} create-stack --stack-name ${PROJECT_NAME} \
                --template-body file://cloudformation/staging/cloudformation.staging.eks.master.yml \
                --parameters \
                ParameterKey="VPCCIDR",ParameterValue="10.0.0.0/16" \
                ParameterKey="PublicSubnet1CIDR",ParameterValue="10.0.0.0/24" \
                ParameterKey="PublicSubnet2CIDR",ParameterValue="10.0.1.0/24" \
                ParameterKey="PrivateSubnet1ACIDR",ParameterValue="10.0.10.0/24" \
                ParameterKey="PrivateSubnet2ACIDR",ParameterValue="10.0.11.0/24" \
                ParameterKey="AllowedWebBlock",ParameterValue="${CURRENT_LOCAL_IP}" \
                ParameterKey="DbMasterPassword",ParameterValue="super_secret" \
                ParameterKey="QSS3BucketName",ParameterValue="${PROJECT_NAME}-${AWS_REGION}" \
                ParameterKey="QSS3KeyPrefix",ParameterValue="staging" \
                ParameterKey="VPNInstanceKeyName",ParameterValue="${VPN_KEY_NAME}" \
                --capabilities CAPABILITY_NAMED_IAM

vpn:
		echo '$(shell aws s3 cp s3://${VPN_CERTS_BUCKET}/client/stagingVPNClient.zip ~/Downloads/${PROJECT_NAME}VPNClient/)' && \
        unzip ~/Downloads/${PROJECT_NAME}VPNClient/stagingVPNClient.zip -d ~/Downloads/${PROJECT_NAME}VPNClient && \
        nmcli con import type openvpn file ~/Downloads/${PROJECT_NAME}VPNClient/staging_vpn_clientuser.ovpn

clean:
		aws cloudformation delete-stack --stack-name ${PROJECT_NAME} && \
		rm -r ~/Downloads/${PROJECT_NAME}VPNClient && \
		nmcli con delete staging_vpn_clientuser
