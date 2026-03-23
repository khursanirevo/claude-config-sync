# Installation Guide

## Claude Code (Local Path)

```bash
# From local directory
/plugin install /home/user/superpowers-lab
```

Replace `/home/user/superpowers-lab` with the actual path to your superpowers-lab directory.

## Verification

Start a new session and ask:

```text
Help me design an experiment
```

The agent should invoke the `experiment-planning` skill automatically.

## Manual Installation

If the plugin system doesn't work:

1. Copy skills to your Claude skills directory
2. Add session-start hook to your hooks
3. Restart Claude Code

See Claude Code documentation for manual installation details.

## Troubleshooting

**Skills not triggering:**
- Ensure session-start hook is running
- Check skills are in correct directory
- Try: "Use experiment-planning skill" (manual invocation)

**File permission errors:**
- Ensure hooks/session-start is executable: `chmod +x hooks/session-start`

**Plugin not found:**
- Verify the path to superpowers-lab is correct
- Check that the directory contains a `.claude-plugin/plugin.json` file
- Try using an absolute path instead of a relative path

**Session-start hook not executing:**
- Verify the hook file has execute permissions: `chmod +x hooks/session-start`
- Check that the hook is in the correct location: `hooks/session-start`
- Look for any error messages in the Claude Code logs when starting a new session
