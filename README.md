# 2-Tier AWS Architecture: Public Nginx Reverse Proxy & Private App Server

A hands-on, step-by-step guide to deploying a secure **2-Tier Architecture** on AWS within the **Free Tier**. This project demonstrates core cloud networking concepts, including custom VPC design, subnet isolation, route tables, security group chaining, and reverse proxying with Nginx.

---

## 📐 Architecture Overview

```text
               Internet
                  │
                  ▼
        ┌───────────────────┐
        │ Internet Gateway  │
        └─────────┬─────────┘
                  │
 ┌────────────────┼────────────────────────────────────────────┐
 │ VPC (10.0.0.0/16)                                           │
 │                                                             │
 │   ┌─────────────────────────────────────────────────────┐   │
 │   │ Public Subnet (10.0.1.0/24)                         │   │
 │   │   - Route Table -> Internet Gateway                 │   │
 │   │                                                     │   │
 │   │   ┌─────────────────────────────────────────────┐   │   │
 │   │   │ Public EC2: Nginx Reverse Proxy             │   │   │
 │   │   │ Security Group: Allow HTTP (80) & SSH (22)  │   │   │
 │   │   └──────────────────────┬──────────────────────┘   │   │
 │   └──────────────────────────┼──────────────────────────┘   │
 │                              │ Internal Traffic (Port 8080) │
 │   ┌──────────────────────────┼──────────────────────────┐   │
 │   │ Private Subnet (10.0.2.0/24)                        │   │
 │   │   - Route Table -> Local Only (No Internet)         │   │
 │   │                                                     │   │
 │   │   ┌─────────────────────────────────────────────┐   │   │
 │   │   │ Private EC2: Application Server             │   │   │
 │   │   │ Security Group: Allow Port 8080 & SSH (22)  │   │   │
 │   │   │                 ONLY from Public EC2 SG     │   │   │
 │   │   └─────────────────────────────────────────────┘   │   │
 │   └─────────────────────────────────────────────────────┘   │
 └─────────────────────────────────────────────────────────────┘
```

---

## 💡 Key Architectural & Security Concepts Demonstrated

1. **Subnet Isolation:** Subnets are created identical in AWS. Their public/private status is defined entirely by whether their associated **Route Table** contains a route (`0.0.0.0/0`) targeting an **Internet Gateway (IGW)**.
2. **Security Group Chaining (Zero Trust):** Instead of restricting incoming database or application server traffic by specific IP addresses, the Private Security Group directly references the **Public Security Group ID (`sg-xxxxxxxx`)** as its source. This ensures only instances tagged with the public security group can communicate with the private layer.
3. **Defense-in-Depth:** Even if the private EC2 instance accidentally receives a public IP or misconfigured firewall rule, it remains completely unreachable from the internet because the subnet's route table lacks a route to the Internet Gateway.

---

## 🛠️ Prerequisites

* An active **AWS Account** (Free Tier eligible).
* Basic familiarity with the Linux command line and SSH.
* An SSH key pair created in your target AWS region.

---

## 🚀 Step-by-Step Implementation Guide

### Phase 1: Custom VPC & Internet Gateway

1. **Create the VPC:**
   * Go to **AWS Console > VPC Dashboard > Your VPCs** and click **Create VPC**.
   * Select **VPC only**.
   * **Name tag:** `practice-vpc`
   * **IPv4 CIDR block:** `10.0.0.0/16`
   * Click **Create VPC**.

2. **Create & Attach the Internet Gateway (IGW):**
   * Go to **Internet Gateways** > click **Create internet gateway**.
   * **Name tag:** `practice-igw`
   * Click **Create internet gateway**.
   * Click **Actions > Attach to VPC**, select `practice-vpc`, and click **Attach internet gateway**.


**Note:** when creating a VPC it will automatically create some other services such as
   * Main Route Table: Contains only local route
   * Default Security Group: Allows inbound from self, all outbound
   * Default Network ACL: Allows ALL inbound and outbound traffic

---

### Phase 2: Subnet Configuration

1. **Create the Public Subnet:**
   * Go to **Subnets** > click **Create subnet**.
   * **VPC ID:** `practice-vpc`
   * **Subnet name:** `public-subnet-1a`
   * **Availability Zone:** Select your preferred zone (e.g., `us-east-1a`).
   * **IPv4 CIDR block:** `10.0.1.0/24`
   * Click **Create subnet**.

2. **Enable Auto-Assign Public IP:**
   * Select `public-subnet-1a`.
   * Click **Actions > Edit subnet settings**.
   * Check **Enable auto-assign public IPv4 address** and click **Save**.

**Note:** This setting is required so when we create an instance on this subnet it will automatically get a public ip for us to access it via ssh or http

3. **Create the Private Subnet:**
   * Click **Create subnet**.
   * **VPC ID:** `practice-vpc`
   * **Subnet name:** `private-subnet-1a`
   * **Availability Zone:** Select the same zone (e.g., `us-east-1a`).
   * **IPv4 CIDR block:** `10.0.2.0/24`
   * Click **Create subnet** *(Leave auto-assign public IP disabled)*.

---

### Phase 3: Route Table Management

By default, all subnets attach to the VPC's Main Route Table (local traffic only). We keep the Main Route Table private and create a dedicated Route Table for the public subnet.

1. **Create Public Route Table:**
   * Go to **Route Tables** > click **Create route table**.
   * **Name tag:** `public-rt`
   * **VPC:** `practice-vpc`
   * Click **Create route table**.

2. **Add Internet Route:**
   * Select `public-rt` > go to the **Routes** tab > click **Edit routes**.
   * Add Route:
     * **Destination:** `0.0.0.0/0`
     * **Target:** **Internet Gateway** -> `practice-igw`
   * Click **Save changes**.

3. **Associate Public Subnet:**
   * Under the **Subnet associations** tab for `public-rt`, click **Edit subnet associations**.
   * Select `public-subnet-1a` and click **Save associations**.

---

### Phase 4: Security Groups Configuration

1. **Public Security Group (`public-ec2-sg`):**
   * Go to **EC2 Dashboard > Security Groups** > click **Create security group**.
   * **Name:** `public-ec2-sg` | **VPC:** `practice-vpc`
   * **Inbound Rules:**
     * `HTTP` (Port 80) | Source: `0.0.0.0/0`
     * `SSH` (Port 22) | Source: `My IP`
   * Click **Create security group**.

2. **Private Security Group (`private-ec2-sg`):**
   * Click **Create security group**.
   * **Name:** `private-ec2-sg` | **VPC:** `practice-vpc`
   * **Inbound Rules:**
     * `Custom TCP` (Port 8080) | Source: **`public-ec2-sg`** (Select Security Group ID)
     * `SSH` (Port 22) | Source: **`public-ec2-sg`** (Select Security Group ID)
   * Click **Create security group**.

---

### Phase 5: Launching EC2 Instances

1. **Launch Private App Server:**
   * **Name:** `private-app-server`
   * **AMI:** Amazon Linux 2023 | **Instance Type:** `t3.micro` (or `t2.micro`)
   * **Key pair name:** select the key pair to access via ssh
   * **Network:** `practice-vpc`
   * **Subnet:** `private-subnet-1a` | **Auto-assign Public IP:** Disable
   * **Security Group:** `private-ec2-sg`
   * *Note down its Private IP Address (e.g., `10.0.2.x`).*

2. **Launch Public Web Proxy:**
   * **Name:** `public-web-proxy`
   * **AMI:** Amazon Linux 2023 | **Instance Type:** `t3.micro` (or `t2.micro`)
   * **Key pair name:** select the key pair to access via ssh
   * **Network:** `practice-vpc`
   * **Subnet:** `public-subnet-1a` | **Auto-assign Public IP:** Enable
   * **Security Group:** `public-ec2-sg`
   * *Note down its Public IP Address.*

---

### Phase 6: Application & Nginx Setup

# 1. Configure Private App Server
From your local terminal, SSH into the Public EC2 and jump to the Private EC2:

```bash
# 1. SSH into Public EC2 from laptop
ssh -i /path/to/key.pem ec2-user@<PUBLIC_EC2_PUBLIC_IP>

# 2. SSH from Public EC2 to Private EC2
ssh -i /path/to/key.pem ec2-user@<PRIVATE_EC2_PRIVATE_IP>

# 3. Create a test web page
From this repo copy/paste the script "create_test_web.sh" into the private instance

# 4. Execute script
chmod +x create_test_web.sh
./create_test_web.sh
```

# 2. Configure Nginx Reverse Proxy
Open a new terminal window on your laptop:

```bash
# 1. SSH into Public EC2
ssh -i /path/to/key.pem ec2-user@<PUBLIC_EC2_PUBLIC_IP>

# 2. Install and start Nginx
From this repo copy/paste the script "nginx_setup.sh" 

#3. Execute script
chmod +x nginx_setup.sh
./nginx_setup.sh <PRIVATE_EC2_PRIVATE_IP>
```

Validate and reload Nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🧪 Verification

1. Open your browser and navigate to `http://<PUBLIC_EC2_PUBLIC_IP>`.
2. You should see the response: **`Hello from the Private Subnet App Server!`**
3. Attempting to directly curl or ping the Private IP from outside the VPC will fail, confirming full network isolation.

---

## 🧹 Cleanup Instructions

To avoid unexpected charges after testing:
1. Terminate both EC2 Instances (`public-web-proxy` and `private-app-server`).
2. Delete the Custom VPC (`practice-vpc`), which will automatically clean up attached Subnets, Security Groups, Route Tables, and Internet Gateways.
