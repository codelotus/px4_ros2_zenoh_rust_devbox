## PX4 ROS2 Zenoh Rust Dev Environment

Docker container to be used as a dev container for a PX4 development project in VSCode, or [Cursor](https://www.cursor.com/).

Tested on a WSL2 Ubuntu 22.04 running on Windows 11 

### Useful commands....

```bash
# Build the image (v1.15.0 is the PX4 version in the container)
$ docker build --platform linux/amd64 -t px4_ros2_zenoh_rust_devbox:v1.15.0 -f Dockerfile .


# Allow X Connections from the container
$ xhost +local:root

# Run a container (notice the --name setting)
$ docker run --gpus all --platform linux/amd64 --name px4 -it --rm -e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix --privileged px4_ros2_zenoh_rust_devbox:v1.15.0

# cd into the home folder and launch a tmux session that launches px4 sitl and qGroundControl
$ cd ~
$ tmuxp load tmux_session.yaml
```
