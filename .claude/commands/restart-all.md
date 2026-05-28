---
description: Shut down all simulators, boot 3 devices, rebuild MbengkelIn, and reinstall + relaunch on all three
---

Run the project script that reinstalls and restarts the app on 3 simulators at once:

```sh
bash scripts/restart-all.sh
```

Run it in the background if the build is slow. Report which simulators the app launched on, and surface any build errors from the output.
