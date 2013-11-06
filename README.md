CitySDK Deploy
==============

How to setup an Ubuntu 12.04 LTS server and deploy CitySDK on it

Set up
------

Arch Linux users should run

    # ./scripts/setup/arch.sh


Deploy
------

1.  Copy the `setup.sh` script from the `src` directory to the target machine.

2.  Execute the `setup.sh` script on the target machine. You may be prompted
    for your `sudoer` password multiple times while the script executes.


Testing
-------

The deployment can be tested using VirtualBox. The `vb-create.sh` in the
`scripts` directory creates a suitable virtual machine. Once created, Ubuntu
12.04 LTS should be installed. From this point you should be able to deploy
CitySDK onto the virtual machine following the instructions above.

