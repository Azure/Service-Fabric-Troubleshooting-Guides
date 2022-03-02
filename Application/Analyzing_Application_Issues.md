# Analyzing Application issues for services deployed to an Azure Service Fabric Cluster

Applications deployed to an Azure Service Fabric cluster can face issues due to various reasons and in most cases Application code or config can cause these issues. Since the Application team understands the architecture of the application and its dependencies, they are in the best position to quickly determine cause and resolve it. Sometimes (not always) Service Fabric CSS team can provide insights from Service Fabric logs to speedup investigation by Application team. During these interactions between the customer team and SF CSS team for Application issues, it is important that Application team engineers are engaged directly in the communications, and they provide requested information in a timely manner. It is also important for application team to provide details of their investigations, as early as possible ideally when opening the case.

While SF CSS team can help with investigations, the final responsibility of analyzing and determining the root cause of Application issues is the Application team. If the Application team after their analysis suspect some behavior of Service Fabric to be the cause for Application issue, application team should provide details of their investigation to help speed up investigation by SF CSS team.

### Common causes

1. Failing on startup
    1. [Diagnose common code package errors by using Service Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-code-package-errors)
    2. Loading data can delay opening, responsiveness, or might cause unforeseen exceptions and timeouts. 
    1. Exceeding hardware resources
    1. Unhandled exceptions or dependencies in code
    1. Failing on external services, authorization, unhandled error codes, request timeouts
    1. Recent code changes through application deployments
1. Failures with certificates 
    1. Certificate not available on machine
    1. Private key is missing
    1. Insufficient permissions to access certificates or their private keys. For example: [How to set ACL for a SF certificate](../Security/Set%20ACL%20for%20a%20SF%20certificate.md).
1. Missing assembly dependencies
    1. Required .NET version not available
    1. Assemblies are missing in app package
1. Failures with application identity, process runs with insufficient user permissions
1. Application blocked on node by Service Fabric runtime after too many failed process starts
1. Resource exhaustion by noisy neighbors, shared processes
1. Exhaustion of [SNAT ports](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#exhausting-ports) or TCP connections
1. Application not honoring cancellation token, eg. code execution stuck on reconfiguration 

### Minimum troubleshooting investigation

1. Application Logs
    1. [Diagnose common scenarios with Service Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-common-scenarios)
    2. [Add logging to your Service Fabric application](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-how-to-diagnostics-log)
    3. [Event analysis and visualization with Application Insights](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-analysis-appinsights)
    4. [Monitor containers with Azure Monitor logs](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-oms-containers)
1. System Event Log
    1. Application, System, Security
    1. Operational cluster events
        1. [Event aggregation and collection using Windows Azure Diagnostics](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-aggregation-wad)
        2. [Service Fabric Linux cluster events in Syslog](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-oms-syslog)
1. Performance Counter (CPU, Memory, Disk IO, Disk capacity, Network)
    1. [How can I monitor performance counters?](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-common-scenarios#how-can-i-monitor-performance-counters)
1. Service Fabric Explorer 
    1. Any errors/warnings related to apps, eg. EventStore for cluster and applications
    2. [Cluster system health reports to troubleshoot](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-understand-and-troubleshoot-with-system-health-reports)

### Best practices

Recommendations to help Application owner analyze application issues in distributed environment

1. Log liberally in your applications
    1. Log success as well as failures
    1. Failure logs should be verbose and capture as much of the context as possible
1. Use correlation IDs in logs to allow tracing through the application code to pinpoint failure context
1. Get familiar with common debugging tools and techniques for distributed environment
1. Get familiar with [Process Dump Analysis by using WinDbg Preview](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/debugging-using-windbg-preview)
1. Setup alerts on monitoring for hot paths and critical design thresholds
1. Have defined a process for the escalation path
1. Know your bottlenecks by load and performance testing every release

### Types of application issues where SF CSS team may be able to provide good insights for helping Application team with investigation 

Service Fabric logs collect information about service fabric cluster and very minimal information about the applications themselves. Service Fabric does not have insights into the internals of the application and hence does not have the ability to capture information about the application behavior. Service Fabric has knowledge about the following and can provide some insights to help with application but not necessarily the exact cause.

- Service lifecycle events i.e. startup, role change, shutdown and any abnormal behavior during these phases

### Types of application issues where SF CSS team may be able to provide insights with additional information from customer for helping Application team with investigation

Service Fabric has no knowledge into the following. In some cases, SF CSS team may be able to help with narrowing down / directing application team with possible investigation paths with additional information but it is on a best effort basis. Responsibility of analyzing the issues on the Application team.

- Performance
- Crashes
- Interaction between the application and the SF runtime (if it exists)
- Set up of application resources by the SF runtime (accounts, certificates, endpoints)
- Connection handshakes for apps built on the SF SDK

Please note that, with a few exceptions, SF logs are diagnostic traces, and do not constitute an audit.

### Types of application issues where SF CSS team will not be able to help

- Connectivity issues from the services to external entities

### Types of issues where SF CSS team may be able to help if there is an active repro

- Unexpected behaviors with Service Fabric SDK not aligned with official documentation

Investigation details to be shared by Application team when they suspect SF to be the cause

- Service Fabric API in question
    - Call stack
    - Parameters passed to the API
    - Code snippet that makes the SF API call
    - Retry policy when applicable to handle transient exceptions
    - Version of Service Fabric SDK, .NET framework, etc.
    - Detailed steps for repo

Resources for application team to help with analyzing and resolving issues in Applications deployed in distributed environment.

For reproducible behaviors on Azure hosted clusters provide timestamp of a isolated sample.

## Further reading 

- [List of Service Fabric operational events](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-generation-operational)
- [Diagnostics and performance monitoring for Reliable Actors](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-actors-diagnostics)
- [Diagnostic functionality for Stateful Reliable Services](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-services-diagnostics)
- [Azure Load Testing](https://azure.microsoft.com/en-us/services/load-testing/#overview) to find bottlenecks in your design early
- [Fault Analysis Service](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-testability-overview) to introduce chaos testing by injecting failures
- [Application monitoring with FabricObserver](https://github.com/microsoft/service-fabric-observer)


## Advanced reading about troubleshooting tools

- [Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
    - [Debug snapshots on exceptions in .NET apps](https://docs.microsoft.com/en-us/azure/azure-monitor/app/snapshot-debugger) (should only be used in production under extreme caution)
    - [Profile production applications in Azure with Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/profiler-overview) (should only be used in production under extreme caution)
    - [Sampling in Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/sampling)
    - [Application Map: Triage Distributed Applications](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-map?tabs=net), call stack, service to service, latency, load numbers
    - [Telemetry correlation in Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/correlation)
    - [Smart detection in Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/proactive-diagnostics) - Finds anomalies in failures, performance, trace degradation, memory leaks, abnormal rise in exceptions, security anti-patterns
- [Azure platform logs](https://docs.microsoft.com/en-us/azure/azure-monitor/essentials/platform-logs-overview) - Logs from data plane and management plane
    - [View metrics across multiple resources](https://docs.microsoft.com/en-us/azure/azure-monitor/essentials/metrics-charts#view-metrics-across-multiple-resources)
- [ProcDump](https://docs.microsoft.com/en-us/sysinternals/downloads/procdump) to capture dumps on hang window, unhandled exceptions, thresholds on performance counter
- [Using DebugDiag to capture memory dumps on First Chance Exception](https://techcommunity.microsoft.com/t5/iis-support-blog/using-debugdiag-to-capture-memory-dumps-on-first-chance/ba-p/377131) (heavy for production)
- [Debug a memory leak in .NET Core](https://docs.microsoft.com/en-us/dotnet/core/diagnostics/debug-memory-leak)
- [Debugging Using WinDbg Preview](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/debugging-using-windbg-preview)
- [SOS debugger extension](https://docs.microsoft.com/en-us/dotnet/core/diagnostics/sos-debugging-extension)
- [Debug a remote Service Fabric application](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-debugging-your-application#debug-a-remote-service-fabric-application)
- [Visual Studio Profiling Tools](https://docs.microsoft.com/en-us/visualstudio/profiling/profiling-feature-tour)
- [Windows Performance Analyzer](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-analyzer)
- [PerfView](https://github.com/Microsoft/perfview)


## Support

If you need more help at any point in this article, you can contact the Azure experts by following our [support options](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-support). Alternatively, you can also file an Azure support incident. Go to the [Azure Support site](https://azure.microsoft.com/support/options/) and click on 'Get Support'.