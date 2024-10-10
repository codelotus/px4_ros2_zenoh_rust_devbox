FROM ubuntu:22.04


# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV PATH=/home/app/.local/bin:$PATH


RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone




# Install general dependencies
RUN apt-get update && apt-get install -y \
   sudo \
   git \
   curl \
   wget \
   vim \
   gnupg2 \
   build-essential \
   cmake \
   python3 \
   python3-pip \
   openjdk-11-jdk \
   x11-apps \
   lsb-release \
   libglib2.0-0 \
   libglu1-mesa \
   libxext6 \
   libxrender1 \
   libx11-xcb1 \
   libxkbcommon-x11-0 \
   libpulse0 \
   libnss3 \
   libasound2 \
   qtbase5-dev \
   qtbase5-dev-tools \
   libgtk-3-dev \
   liblzma-dev \
   qt5-qmake \
   libxcb1-dev \
   libx11-dev \
   libxcb1 \
   libx11-xcb-dev \
   libxrender-dev \
   libxkbcommon-x11-dev \
   mesa-utils \
   libgtk-3-dev \
   libappindicator3-dev \
   librsvg2-dev \
   libgl1-mesa-glx \
   libx11-dev \
   libgl1-mesa-dri \
   libwebkit2gtk-4.0-dev \
   libssl-dev \
   software-properties-common \
   xauth \
   tmux \
   tmuxp \
   ca-certificates \
   && sudo apt-get clean \
   && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*


# Create a non-root user
RUN useradd -ms /bin/bash app && echo 'app:app' | chpasswd && adduser app sudo


# Allow the user to use dudo without a password
RUN echo 'app ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# Switch to non-root user
USER app




# Install ROS2 Humble
WORKDIR /home/app
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | sudo apt-key add - \
   && sudo sh -c 'echo "deb http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list' \
   && sudo apt-get update && sudo apt-get install -y \
   ros-humble-desktop \
   python3-rosdep \
   python3-argcomplete \
   python3-colcon-common-extensions \
   && sudo apt-get clean \
   && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*
RUN sudo rosdep init \
   && rosdep update --rosdistro humble


# Setup environment
SHELL ["/bin/bash", "-c"]
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc


# Install PX4 dependencies
RUN sudo apt-get update && sudo apt-get install -y \
   python3-jinja2 \
   python3-empy \
   python3-toml \
   python3-numpy \
   python3-yaml \
   python3-setuptools \
   python3-future \
   python3-pip \
   openocd \
   flex \
   bison \
   libncurses5-dev \
   libncursesw5-dev \
   autoconf \
   automake \
   libtool \
   curl \
   unzip \
   protobuf-compiler \
   libeigen3-dev \
   genromfs \
   ninja-build \
   exiftool \
   v4l-utils \
   libxml2-dev \
   libxslt1-dev \
   && pip3 install pyros-genmsg pyros-common kconfiglib jsonschema \
   && sudo apt-get clean \
   && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*


# Install Micro XRCE-DDS Agent
WORKDIR /home/app/Micro-XRCE-DDS-Agent
RUN git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git /home/app/Micro-XRCE-DDS-Agent && \
   mkdir /home/app/Micro-XRCE-DDS-Agent/build
WORKDIR /home/app/Micro-XRCE-DDS-Agent/build
RUN cmake .. && \
   make -j$(nproc) && \
   sudo make install


# Clone and build PX4
WORKDIR /home/app/PX4-Autopilot
RUN git clone --depth 1 --branch v1.15.0 https://github.com/PX4/PX4-Autopilot.git --recursive /home/app/PX4-Autopilot
RUN bash /home/app/PX4-Autopilot/Tools/setup/ubuntu.sh
RUN DONT_RUN=1 make px4_sitl_default


# Copy QGroundControl.AppImage to the container
RUN sudo apt install gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl -y
RUN sudo apt install libfuse2 -y
RUN sudo apt install libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor0 -y


USER app
WORKDIR /home/app
RUN curl --output QGroundControl.AppImage https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage
COPY QGroundControl.AppImage /home/app/QGroundControl.AppImage
RUN sudo chmod +x /home/app/QGroundControl.AppImage
RUN ./QGroundControl.AppImage --appimage-extract


RUN mkdir -p /home/app/px4_msgs/msg/
RUN cp /home/app/PX4-Autopilot/msg/*.msg /home/app/px4_msgs/msg/

RUN mkdir -p /home/app/px4_ros_com_ros2/src
RUN git clone --depth 1 https://github.com/PX4/px4_ros_com.git /home/app/px4_ros_com_ros2/src/px4_ros_com
RUN git clone --depth 1 --branch 2.0.1 https://github.com/PX4/px4_msgs.git /home/app/px4_ros_com_ros2/src/px4_msgs
WORKDIR /home/app/px4_ros_com_ros2/src

# Zenoh Plugin
RUN echo "deb [trusted=yes] https://download.eclipse.org/zenoh/debian-repo/ /" | sudo tee -a /etc/apt/sources.list > /dev/null && \
  sudo apt update && \
  sudo apt install -y zenoh-bridge-ros2dds

# Install Rust and Cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
 
# Set the working directory
WORKDIR /workspace

# Copy the project files into the container (if any, adjust as needed)
COPY .tmux.conf /home/app/.tmux.conf
COPY tmux_session.yaml /home/app/tmux_session.yaml

# Source ROS2 and PX4 setup scripts on container start
ENTRYPOINT ["bash", "-c", "source /opt/ros/humble/setup.bash && exec bash"]
