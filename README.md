# buildkite-agent-launcher

## Introduction

`buildkite-agent-launcher` queries the Buildkite API for any scheduled/running jobs and launches configured agents to satisfy them. It can be configured to poll Buildkite periodically and/or when a webhook is delivered to it.

Agents are started and monitored using shell commands, so it can be integrated with any combiination of physical machines, virtual machines, containers, etc.

## Configuration

`buildkite-agent-launcher` is configured using a YAML file, like the following:

```yaml
# Buildkite organisation and API token used to check running jobs.
# The token must have the `read_builds` scope.
buildkite organisation: example-inc
buildkite api token: bkua_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Optional HTTP listen port and token for webhook triggering.
# webhook listen port: 1234
# webhook token: abcd

# Query Buildkite for scheduled/running jobs every 30 seconds.
buildkite poll interval: 30

agents:
  # Start the buildkite-agent service when a job is scheduled for the default
  # queue if it isn't already running.
  - tags: queue=default
    check command: systemctl is-active buildkite-agent.service || exit 1
    launch command: systemctl start buildkite-agent.service

  # Send a power on command to bob.example.com when a job is scheduled for the
  # 'bob' queue. This agent can service 4 jobs at once.
  - tags: queue=bob
    check command: ping -c1 -w5 bob.example.com > /dev/null 2>&1
    launch command: powerwake bob.example.com
    spawn: 4
```

### Static agents

A "static agent" is defined with a `check command` option, only one instance of it can be started and it services a fixed number of jobs concurrently.

```yaml
agents:
  - tags: queue=foo,queue=bar
    
    # Command used to check if the agent is already running when considering if
    # it should be started. A return status of 0 indicates it is running, 1
    # indicates it isn't and any other value is treated as an error which will
    # skip the agent.
    check command: systemctl is-active buildkite-agent.service || exit 1
    
    # Command used to start the agent. A return status of zero indicates the
    # agent was started, 75 indicates the agent is in the process of starting
    # and anything else is an error.
    launch command: systemctl start buildkite-agent.service
    
    # The number of jobs this agent will service concurrently. Defaults to 1 if
    # not defined.
    spawn: 2
```

### Dynamic agents

A "dynamic agent" is defined with a `count command` option, multiple instances can be started at once to service more jobs as demand increases.

```yaml
agents:
  - tags: queue=default
    
    # Command used to check how many instances of the agent are running. It
    # should output the number to standard output and exit with status zero.
    count command: (virsh list --state-running --name | grep -c 'build-vm-') || exit 0
    
    # Command used to start another instance of the agent. A return status of
    # zero indicates the agent was started, 75 indicates the agent is in the
    # process of starting and anything else is an error.
    launch command: /script/to/start/another/build-vm
    
    # The number of jobs each instance of this agent will service concurrently.
    # Defaults to 1 if not defined.
    spawn per instance: 2
    
    # The maximum number of instances which may be started. There is no limit
    # if this option is omitted.
    max instances: 10
```
