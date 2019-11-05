define message1
 Environment variable BASE_IP is required. Not set.
 		Use following command:
        "$$ my_ip=`curl ipinfo.io | jq .ip`;eval my_ip=$${my_ip[i]};my_ip="$$my_ip/32"; export BASE_IP=$$my_ip"

endef


ifndef BASE_IP
export message1
$(error $(message1))
endif


# CloudFormation master
CURRENT_LOCAL_IP = $(BASE_IP)
CFN_TEMPLATES_BUCKET := kubeairflow-cloudformation-eu-central-1
AWS_REGION := eu-central-1
PROJECT_NAME := kubeairflow-staging
VPN_KEY_NAME := kubeairflow-staging-bastion

# deployment variables
APPLICATION = $(PROJECT_NAME)-deployment-application
DEPLOYMENT_GROUP = $(PROJECT_NAME)-deployment-group
DEPLOYMENTS_BUCKET = $(PROJECT_NAME)-deployments-eu-central-1
REVISION := $(shell date --utc +%Y%m%dT%H%M%SZ)
PACKAGE = $(PROJECT_NAME)_$(REVISION).tgz

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
                ParameterKey="AllowedWebBlock",ParameterValue="${CURRENT_LOCAL_IP}" \
                ParameterKey="DbMasterPassword",ParameterValue="super_secret" \
                ParameterKey="QSS3BucketName",ParameterValue="${PROJECT_NAME}-${AWS_REGION}" \
                ParameterKey="QSS3KeyPrefix",ParameterValue="staging" \
                --capabilities CAPABILITY_NAMED_IAM

# vpn:
#         aws s3 cp s3://${VPN_CERTS_BUCKET}/client/FlaskApiVPNClient.zip ~/Downloads/FlaskApiVPNClient/
#         unzip ~/Downloads/FlaskApiVPNClient/FlaskApiVPNClient.zip -d ~/Downloads/FlaskApiVPNClient
#         nmcli con import type openvpn file ~/Downloads/FlaskApiVPNClient/flaskapi_vpn_clientuser.ovpn

clean:
		aws cloudformation delete-stack --stack-name ${PROJECT_NAME}
#         rm -r ~/Downloads/FlaskApiVPNClient
#         nmcli con delete flaskapi_vpn_clientuser

# -------------------- Make new airflow deployment---------------------------

package:
	cd airflowapp && tar czf ../$(PACKAGE) .

upload: package
	aws s3 cp $(PACKAGE) s3://$(DEPLOYMENTS_BUCKET)

deploy: upload
	aws deploy create-deployment \
		--application-name $(APPLICATION) \
		--deployment-group-name $(DEPLOYMENT_GROUP) \
		--s3-location bucket=$(DEPLOYMENTS_BUCKET),bundleType=tgz,key=$(PACKAGE) \
		--deployment-config-name CodeDeployDefault.AllAtOnce \
		--file-exists-behavior OVERWRITE
