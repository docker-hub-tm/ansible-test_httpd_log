FROM centos:8 AS builder

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_DEFAULT_REGION
ARG AWSCLI_URL='https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip'
ARG S3_BUCKET
ARG S3_OBJECT

ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
ENV AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

WORKDIR /root

# Install AWS CLI
RUN dnf clean all \
  && dnf install zip unzip sudo -y \
  && curl "$AWSCLI_URL" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && sudo ./aws/install

# Get httpd log files from AWS S3 bucket
RUN aws s3 cp s3://$S3_BUCKET/$S3_OBJECT/ /aws-s3/ --recursive

FROM centos:8

# Install requirements
RUN dnf clean all \
  && dnf update -y \
  && dnf install -y sudo

# Create `ansible` user with sudo permissions
ENV ANSIBLE_USER=ansible SUDO_GROUP=wheel
RUN set -xe \
  && groupadd -r ${ANSIBLE_USER} \
  && useradd -m -g ${ANSIBLE_USER} ${ANSIBLE_USER} \
  && usermod -aG ${SUDO_GROUP} ${ANSIBLE_USER} \
  && sed -i "/^%${SUDO_GROUP}/s/ALL\$/NOPASSWD:ALL/g" /etc/sudoers

# Install httpd
RUN dnf install httpd -y

COPY --from=builder /aws-s3/ /var/log/httpd/
