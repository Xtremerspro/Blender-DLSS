# Blender-DLSS
A simple bat script to build your own DLSS-bundled Blender build

[(Video tutorial)](https://youtu.be/V-XlHF149Qo)

# Steps
1. Download Prerequisites:
- [Cuda](https://developer.nvidia.com/cuda-downloads?target_os=Windows&target_arch=x86_64&target_version=11&target_type=exe_local)
- [Optix](https://developer.nvidia.com/designworks/optix/download)
- [Git](https://git-scm.com/install/windows)
- [Visual Studio](https://visualstudio.microsoft.com/downloads/)

2. Place the bat script in a folder close to the root of your drive (Windows sometimes throws an error if the file paths are too long) with > 30 GB of space
3. Run the script and wait ~ 30 minutes to a few hours
4. Open the "Release" folder and move your build anywhere on your PC

# How to Use
Open a scene in Blender and switch to the rendered view with cycles enabled, then switch the viewport denoiser to DLSS
