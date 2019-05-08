# Overview

These instructions will get you up to speed using this framework on AWS infrastructure. While this framework eliminates substantial development complexity, setup for AWS F1 remains a lengthy process. Optional instructions are provided to get the Mandelbrot application up and running on a local Linux machine without FPGA acceleration. Furthermore, to run with FPGA acceleration, prebuilt images are provided to initially bypass the lengthy builds.

As a preview of the complete process, to get the Mandelbrot application up and running from source code with FPGA acceleration, you will need to:

  - Get an AWS account with access to F1 instances. (This requires a day or two to get approval from Amazon.)
  - Launch and configure a Development Instance on which to compile the OpenCL, Verilog, and Transaction-Level Verilog source code into an Amazon FPGA Image (AFI).
  - Launch and configure an F1 Instance on which to run: the web server, the Host Application, and the FPGA programmed with the image you created on the Development Instance.
  - Open the FPGA-Accelerated Web Application in a web browser.

F1 machines are powerful and expensive. Configured for minimal optimization, hardware compilation of a small kernel takes about an hour. These instructions assume the use of a separate Development Instance, which does not have an FPGA, to save costs. The FPGA kernel can be tested on this machine using "Hardware Emulation" mode, where the FPGA behavior is emulated using simulation and build times are minimal by comparison. For hobby projects, it is not practical to keep either EC2 Instance up and running for extended periods of time. On the other hand, the overhead of using two machines can sometimes result in extra cost and time of its own. Depending upon your goals, you may prefer to simplify your life by using the F1 Instance as your Development Instance, in which case you can skip the instructions below for creating and configuring the Development Instance.

There are many similar tutorials on line to get started with F1. Many are flawed or unclear. We found this  <a href="https://github.com/Xilinx/SDAccel-Tutorials/blob/master/docs/aws-getting-started/RTL/README.md" target="_ blank">Xilinx tutorial</a> to be the best, though we do not recommend following it to the letter. Instead, open this tutorial in its own window, and follow the instructions below which reference this tutorial.



# AWS Account Setup with F1 Access

Follow the "Prerequisites" instructions, noting the following:

  - When choosing a name for your S3 bucket (in step 3 of these instructions), consider who might be sharing this bucket with you. You should use this bucket for the particular fpga-webserver project you are starting. You might share this bucket with your collaborators. The bucket name should reflect your project. You might wish to use the name of your git repository, or the name of your organization, i.e. `fpga-webserver-zcorp`. If you expect to be the sole developer, you can reflect your name (perhaps your AWS username) in the bucket name and avoid the need for a `/<username>` subdirectory.
  - The subdirectories you will use are: `/<username>` if your username is not reflected in your bucket name, and within that (if created), `/dcp`, `/log`, and `/xfer`.

Okay, now, follow the "FOLLOW THE INSTRUCTIONS" link under "Prerequisits". (In case you lose your place, you should be <a href="https://github.com/Xilinx/SDAccel-Tutorials/blob/master/docs/aws-getting-started/PREREQUISITES/README.md" target="_ blank">here</a>.

Press "Back" in your browser when you are finished the Prerequisite instructions (after requesting F1 access).



# Running Mandelbrot Locally

There is a great deal of setup you can do while you wait for F1 access. First, if you have access to a Ubuntu machine (or care to try your luck with an untested platform or provision a Ubuntu machine via Digital Ocean or similar cloud provider), you can play around with the Mandelbrot example without hardware acceleration.

On a Ubuntu 16.04 machine (or try your luck with something different, at let us know):

```sh
sudo apt-get update
sudo apt-get install make g++ python python-pip python-pil python-tornado
# On centos: sudo yum install make g++ python python-pip python-pillow python-tornado (unconfirmed)
cd <wherever you would like to work>
git clone https://github.com/alessandrocomodi/fpga-webserver
cd fpga-webserver
git submodule update --init --recursive  # or ./init
cd apps/mandelbrot/build
make launch
```

The webserver is running. You can open `http://localhost:8888/index.html` in a local web browser and explore Mandelbrot generated in the Python webserver or in the C++ host application.

You can also open `http://localhost:8888/client.html`. Click "Open", click "Init FPGA", enter coords, like 0, 0, zoom: 1, depth 100, "GET IMAGE" or "Start" for a flythrough.

More instructions for the Mandelbrot application are [here](https://github.com/alessandrocomodi/fpga-webserver/tree/master/apps/mandelbrot).



# Create Development Instance

Next you will provision a Development Instance using the "Create" part of the "1. Create, configure and test an AWS F1 instance" instructions. These instructions configure an F1 machine, but you will instead first configure a Development Instance without the FPGA (in case you are still waiting for F1 approval). You'll repeat these instructions later for the F1 Instance after getting approval.

Click the "FOLLOW THE INSTRUCTIONS" link (which take you <a href="https://github.com/Xilinx/SDAccel-Tutorials/blob/master/docs/aws-getting-started/RTL/README.md" target="_ blank">here</a>). As you step through the tabs of the instance creation process in AWS, perform the following additional/modified steps:

  - In "Step 2. Choose an Instance Type" (Step3 of the tutorial instructions): Since we are creating the Development Instance first, select "c4.2xlarge" instead of "f1.2xlarge" on your first pass through these instructions.
  - In "Step 4. Add Storage" (Step 4.2. of the tutorial instructions): I found the default 5GB of Elastic Block Storage to be rather limited for doing anything more than just the tutorial. I would consider 8GB to be a minimum to support development and 12GB to be practical. (For the F1 Instance, assuming you will do most development on the Development Instance, 8GB is probably sufficient.)
  - In "Step 6. Configure Security Group" (Step 5 of the tutorial instructions): after opening the RDP (Remote Desktop Protocol) port, open additional ports to make the Web Server accessible from outside. Under "Inbound":

    - "Add Rule"
    - For "Type" select "Custom TCP Rule" (should be the default), and enter "8880-8889" as port range (by default, we will use port 8888, but let's reserve several).
    - Select or enter a "Source", e.g. "Anywhere" or your IP address for better security.
    - Set "Description", e.g. "development-webserver".
    - For remote desktop, I have had issues with both RDP and VNC. (More on that below.) If you wish to be able to use VNC (from linux), also open up ports 5901-5910.

Do not proceed to "2. Connecting to the Instance with a remote desktop client" just yet.

Note that you can also make configuration changes after creating and launching the instance. Instances can be controlled via the EC2 Dashboard under "Resources", "Running Instances". To open new ports, scroll right (if necessary) and select the security group for your instance. You will use the "Running Instances" page frequently to start and stop your instances (by selecting the instance(s) and setting their state via "Actions", "Instance State").

You can also name your instance, which would be a good thing to do now by clicking the pencil icon, and entering a name, like `fpga-webserver-run-1`.

Be sure not to accidentally leave instances running!!! You should configure monitoring of your resources, but the options seem very limited for catching instances you fail to stop. Also be warned that stopping an instance can fail. I have found it important to always refresh the page before changing machine state. And, be sure your instance transitions to "stopped" state (or, according to AWS support, charging stops at "stopping" state).


## Remote Desktop

For remote desktop access to the EC2 machines, I have used X11, RDP, and VNC from a Linux client. X11 is easiest, but it is far too slow to be practical. RDP and VNC required several days for me to get working. They are usable, but neither has been ideal for me. RDP has a strange issue where dark pixel colors have transparency to windows behind them. With VNC I experienced periodic stalls of several seconds at a time (which may have something to do with my client machine). Please help us refine these instructions as you try them out.

### X11 Forwarding

This is easy and stable, so even though it is not a solution for running Xilinx tool long-term, start with X11.

```sh
ssh -X -i <AWS key pairs.pem> centos@<ip>
sudo yum install xeyes -y   # Just a GUI application to test X11.
xeyes   # You'll probably see a "Display not set" error.
sudo yum install xorg-x11-xauth
exit
ssh -X -i <AWS key pairs.pem> centos@<ip>
xeyes  # Hopefully, you see some eyes now.
```

### RDP

Next you will continue through "2. Connecting to the Instance with a remote desktop client". (In case you got lost, that's <a href="https://github.com/Xilinx/SDAccel-Tutorials/blob/master/docs/aws-getting-started/RTL/STEP1.md#2-connecting-to-the-instance-with-a-remote-desktop-client" target="_blank">here</a>.)

I encountered the following issues:

  - The `curl`ed script produced an error that `/usr/src/kernels/3.10.0-957.10.1.el7.x86_64` couldn't be found. I changed the link to point to `/usr/src/kernels/3.10.0-862.11.6.el7.x86_64`.
  
  - I was unable to connect from Linux and Windows 7 (for which support ends in Jan. 2020, so stop using it). I found the following fix.

  ```sh
  sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak  # create a backup
  sudo sed -i s/security_layer=negotiate/security_layer=rdp/ /etc/xrdp/xrdp.ini  # change "security_layer"
  sudo diff /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak  # just to see that something changed
  ```

### RDP Desktop (DELETE ME if the above works)

I first tried following an [AWS tutorial from Reinvent 2017](https://github.com/awslabs/aws-fpga-app-notes/tree/master/reInvent17_Developer_Workshop) that used RDP, but I was unsuccessful. (Note, that participants were provided a custom AMI to start from.) In case it helps to debug issues, or in case you need to connect from Windows, this is what I did following the Reinvent 2017 instructions:

In place of:
```sh
source <(curl -s https://s3.amazonaws.com/aws-ec2-f1-reinvent-17/setup_script/setup_reinvent.sh)
```

I extracted the following commands:
```sh
sudo yum install -y kernel-devel # Needed to re-build ENA driver
sudo yum groupinstall -y "Server with GUI"
sudo systemctl set-default graphical.target

sudo yum -y install epel-release
sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
sudo yum install -y xrdp tigervnc-server
sudo yum install -y chromium
sudo systemctl start xrdp
sudo systemctl enable xrdp
sudo systemctl disable firewalld  # Probably non-existent
sudo systemctl stop firewalld     #  "
```

And I attepted to connect using Remmina from my Ubuntu machine without success. Likely the above "security_layer" fix was the problem.


### VNC from Linux Client

After much struggling, I was able to get VNC working with the Xfce desktop environment.

On the EC2 Instance:

```sh
sudo yum install tigervnc-server
vncpasswd  # Provide password for VNC desktop (and, optionally, a different password for view-only access)
```

```sh
sudo yum install -y epel-release  # (should already be installed)
sudo yum groupinstall -y "Xfce"
```
(I do not think a reboot is necessary.)

Edit ~/.vnc/xstartup to contain:

```sh
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
/etc/X11/xinit/xinitrc
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
vncconfig -iconic &
#xterm -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
startxfce4 &
```

And make it executable:

```sh
chmod +x ~/.vnc/xstartup
```

The VNC Server can be started with:

```sh
vncserver  # Optionally -geometry XXXXxYYYY.
```

The output of this command indicates a log file. You should take a look. I got a number of warnings and a DBus permission error, but they did not appear to be fatal.

From the client:

```sh
vncviewer <IP>:1 passwd=<home>/.vnc/passwd
```

And kill on the remote instance with:
```sh
vncserver -kill :1
```

Any number of clients can be connected to this server while it is running. Closing the client connection does not terminate the server.

After you see that these commands are working, the script `vnc_ec2` (at the top level of the repo) can be used locally to launch a server on the remote instance and connect to it. Note the prerequisite "Assumptions" in the header comments of this file.

```sh
vnc_ec2 -gXXXXxYYYY <IP>   # where -g is the VNC --geometry argument specifying desktop size.
```

This running VNC server should be killed using:

```sh
vnc_ec2 -k <IP>   # <IP> can be omitted to use the IP of the last server launched w/ vnc_ec2.
```


# One-Time Instance Setup

Log into your instance:

```sh
ssh -i <AWS key pairs.pem> centos@<ip>`
```

## S3 Storage

We will share files between instances using Amazon S3 through folders of the form `s3://<bucket-name>[/<unique-username>]/<kernel-name>`. If your bucket is to be shared by multiple users, you should choose a `<unique-username>`, such as your Amazon IAM username.

Configure your `.bashrc` for your bucket and username:

```sh
echo 'export S3_BUCKET=<bucket-name>' >> ~/.bashrc
echo 'export S3_USER=<unique-username>' >> ~/.bashrc   # Exclude this if the bucket is for a single user.
source ~/.bashrc
```

These settings are recognized by the Makefile. Use the same bucket name and user name for all your instances.

## Workdisk

Because disk space is limited, unlike other online instructions, I chose to use the ESB disk for my work:

```sh
ln -s /home/centos/src/project_data workdisk
cd ~/workdisk
```

## AWS CLI Configuration

Configure by providing your credentials. These can be found in in the Security Credentials page, which I'm not sure how to navigate to, but here's a <a href="https://console.aws.amazon.com/iam/home?#/security_credential" target="_ blank">direct link</a>.

Use region: `us-east-1` and output: `json`.

```sh
aws configure
```


## SSH keys

If you happen to be using private git repositories or need passwordless authentication from your instance for any other reason, you may need to generate ssh access keys for your instance.

```sh
ssh-keygen -o -t rsa -b 4096 -C "<machine-identifying comment>"
sudo yum install xclip
xclip -sel clip < ~/.ssh/id_rsa.pub
```

And paste this SSH key into the settings of your other account (e.g. gitlab).


## Clone Necessary Repos

```sh
cd ~/workdisk
git clone https://github.com/aws/aws-fpga.git $AWS_FPGA_REPO_DIR
git clone https://github.com/alessandrocomodi/fpga-webserver
cd fpga-webserver
git submodule update --init --recursive  # or ./init
```



# With Each Login

```sh
source fpga-webserver/sdaccel_setup
```



# FPGA Build

On your Development Instance, build host and Amazon FPGA Image (AFI) that the host application will load onto the FPGA.

```sh
cd ~/workdisk/fpga-webserver/apps/mandelbrot/build
mkdir ../out
make build TARGET=hw KERNEL=mandelbrot -j8 > ../out/out.log &
```

TODO: What about hw_emu target and running in emulation?

This produces output files in `/fpga-webserver/apps/mandelbrot/out/hw/xilinx_aws-vu9p-f1_4ddr-xpr-2pr_4.0/`. Additionally, the final step, the AFI creation, produces a `.tar` file on S3 storage asynchronously in `s3://fpga-webserver/<user-id>/mandelbrot/AFIs/*.tar`. (You configured `<user-id>` in your `~/.bashrc`). You can see it with:

```sh
aws s3 ls s3://fpga-webserver/<user-id>/mandelbrot/AFIs/
```

It also produces `/fpga-webserver/apps/mandelbrot/out/hw/xilinx_aws-vu9p-f1_4ddr-xpr-2pr_4.0/mandelbrot.awsclbin` which references the S3 tarball.



# Building from Source

Now, build both the FPGA image and host application, transfer them to the F1 instance, and run as follows.


## Check Version

These instructions were last debugged with SDx v2018.2. Check to see what you are in for:

```sh
sdx -version
```



# F1 Instance Setup

Once you have been granted access to F1, provision an F1 Instance as you did the Development Instance. Use instance type "f1.2xlarge". `ssh` into this instance. It is useful to provision each machine similarly, as you might find yourself doing builds on the F1 Instance as well as on the Development Instance.


# Running on FPGA

Prebuilt files are included in the repository. Try to run using those first, so you can see the FPGA in action. (TODO: You probably won't have permission to do this. This is probably something to look into.)

```sh
cd
git clone https://github.com/alessandrocomodi/fpga-webserver
cd fpga-webserver
git submodule update --init --recursive  # or ./init
cd apps/mandelbrot/build
make PREBUILT=true TARGET=hw KERNEL=mandelbrot launch
```

Point a web browser at `http://<IP>:8888` and play with the application.

When you are done, _`ctrl-C`_, `exit`, and stop your instance.



# Transfer files and Run

All development is done on the Development Instance. The F1 Instance is just used to run. `fpga-webserver/apps/mandelbrot/` is transferred from the Development Instance to the F1 Instance in its entirety through S3 storage.


## Push

You can transfer your app directory to run on the FPGA using the `push` Make target (which runs an `aws s3 sync` command) and by explicitly running an `aws s3 sync` command to pull. Though the whole directory is copied, the files of importance are:

  - the python webserver (including client content) (everything in `fpga-webserver/apps/mandelbrot/webserver`)
  - the host application (built via intermediate Make target `host`)
  - the `.awsxclbin` (AFI) image (which references `s3://fpga-webserver/<user-id>/mandelbrot/AFIs/`)
  - `launch` script in `fpga-webserver/apps/mandelbrot/build`

```sh
cd ~/workdisk/fpga-webserver/apps/mandelbrot/build
make push TARGET=hw KERNEL=mandelbrot &
```


## Pull

Now, start and log into your F1 Instance, initialize and configure AWS and pull these files:

```sh
mkdir ~/work
cd ~/work
mkdir mandelbrot
cd mandelbrot
aws s3 sync s3://fpga-webserver/<user-id>/mandelbrot/xfer .
```


## Launch

```sh
cd ~/mandelbrot_work/build
chmod +x launch ../out/*/*/host # execute privs lost in transfer
./launch hw
```


## Run

As you did locally, you can access `http://<IP>:8888/index.html`. Now you can utilize the FPGA to generate images.



# Development of this Framework

These are WIP notes:


## SDAccel

This is how I was able to generate an RTL kernel in SDAccel manually and run hardware emulation. This is scripted as part of the build process, but not with the ability to run in SDAccel. These are notes to help figure that out.

 - `cd ~/workdisk/fpga-webserver`
 - `source sdaccel_setup`
 - `sdx`
 - `echo $AWS_PLATFORM` (You will need to know this path.)
 - On Welcome screen "Add Custon Platform".
   - Add (+) `$AWS_PLATFORM/..` .
 - "New SDxProject":
   - Application.
   - name it, select only platform, accept linux on x86 and OpenCL runtime, and "Empty Application". "Finish".
 - Menu "Xilinx", "Create RTL Kernel".
   - name it; 2 clocks (independent kernel clock); 1 reset?
   - default scalars (or change them)
   - default AXI master (Global Memory) options (or change them)
   - wait for Vivado
 - In Vivado:
   - "Generate RTL Kernel"
   - wait
   - Close
 - Back in SDAccel:
   - in projects.sdx:
     - Add binary container under "Hardware Functions" by clicking the lightning bolt icon. There should be only one function identified as the target for the kernel. Click "OK". You will get "binary_container_1".
     - Select "Emulation-HW"
  - Menu "Run", "Run Configuration"
    - Tab "Main", "Kernel Debug", Check "Use RTL waveform...", and check "Launch live waveform".
    - Tab "Arguments", check "Automatically add binary container(s) to arguments"
    - Click "Run" (or "Apply" and click green circle w/ play arrow).

