# wakatime-vfp
This small FoxPro program will send usage data to [wakatime.com](https://wakatime.com) from the Visual FoxPro IDE

# Preparation
You need an account at [wakatime.com](https://wakatime.com). In the profile settings you will find your API key.

# Installation
Just copy the `wakatime.prg` on your dev machine, compile it using FoxPro and call it with these parameters:
```vfp
local lcKey,lcProxy,lcLogFile
lcKey="<Your wakatime API key>"
lcProxy="<optional HTTP proxy>"
lcLogFile="<optional file path for logging>"

wakatime(lcKey,lcProxy,lcLogFile)
```
You may include this call in your `start program` for the VFP IDE

# Remarks
Sadly it is not possible to act on all development actions inside the VFP IDE and send them to wakatime. It is also not possible to aquire the full file paths of classes, forms and so on... So this plugin is quite limited =(
If you know better, please let me know ;)

# Changelog
## Version 1.0
 - Initial release with basic wakatime support 

# Support me <3
If you like my work, please consider supporting it =]  
And donate via [PayPal](https://www.paypal.com/donate?hosted_button_id=37PBGZPHXY8EC)