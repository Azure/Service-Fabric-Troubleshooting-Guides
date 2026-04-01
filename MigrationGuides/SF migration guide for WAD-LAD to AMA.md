---
title: WAD/LAD → AMA + DCR (Log Analytics only) Migration Plan (Service Fabric)
---

# Why this migration

- The Azure Diagnostics extensions for Windows and Linux (WAD/LAD) are deprecated and retire on **March 31, 2026**. Migration to **Azure Monitor Agent (AMA)** configured by **Data Collection Rules (DCRs)** is a supported option to continue collecting guest OS logs and performance data. [Microsoft Learn: AMA migration from WAD/LAD](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-wad-lad)

- Guidance also calls out removing WAD/LAD after AMA is configured to avoid duplicate ingestion. [Microsoft Learn: Diagnostics extension overview](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/diagnostics-extension-overview)

# Phased approach

## Phase A --- Prove AMA + DCR pipeline (non‑SF signals first)

Goal: Stand up AMA and minimal DCRs and confirm data lands in **Log Analytics** before tuning for Service Fabric.

### Exit criteria

- AMA installed and at least one DCR associated (collection starts only after association). [Install/manage AMA](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage)

- Log Analytics shows:

  - Windows event logs (Event table) via DCR Windows Events collection. [DCR samples](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples)

  - Linux syslog (Syslog table) via DCR Syslog collection. [Collect syslog](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-syslog)

  - Performance counters (Perf table) via DCR perf collection. [Collect perf counters](https://outlook.office365.com/owa/?ItemID=AAMkADZjNTFjNTZiLWFkNTAtNDQwOS04NWFhLTQyM2M0NmMyOTg0MQBGAAAAAADxdGEF6q3OS4rjAjxrfVDUBwB1G834VyGwT5QOtVkK5HcPAAO2uE%2bhAAB1G834VyGwT5QOtVkK5HcPAAO2uXJrAAA%3d&exvsurl=1&viewmodel=ReadMessageItem)

- DCR processing/transform/delivery errors are not persistent (use DCR monitoring). [Monitor DCR data collection](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-monitor)

### How-to references (public)

- Create DCRs (portal/JSON): [Create DCRs](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-create-edit)

- Sample DCR JSON patterns: [DCR samples](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples)

- AMA install & association options: [Install/manage AMA](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage)

## Phase B --- Add Service Fabric signals (inventory → DCR mapping)

Goal: Capture what SF signals you rely on today, then configure DCRs to collect them into Log Analytics.

Service Fabric events can be accessed through Windows Event Logs (Windows), and SF exposes platform events through EventStore and log channels. [Service Fabric events overview](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-events)

### Exit criteria

- Inventory worksheet completed (below).

- SF‑focused DCR updates deployed to a canary scope and SF signals appear in Log Analytics (Event/Syslog/Perf/custom tables as applicable).

- DCR monitoring indicates no persistent ingestion/transform/delivery failures. [Monitor DCR data collection](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-monitor)

## Phase C --- Cutover (remove WAD/LAD)

Goal: Once AMA+DCR covers required signals, remove WAD/LAD to avoid duplicates and align with supported path. [AMA migration guidance](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-wad-lad)

**Exit criteria**

- WAD/LAD extension removed from target scope.

- Signals continue to flow via AMA+DCR into Log Analytics and DCR health remains clean. [Monitor DCR data collection](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-monitor)

## Phase B --- Customer Inventory Worksheet (fill‑in)

## 1) Environment / Scope

- Subscription(s):

- Resource group(s):

- Cluster type: Classic (VM/VMSS) / Managed cluster / Other:

- OS: Windows / Linux / Mixed

- Regions:

- Node types / VMSS names:

- Approx node count:

- Target Log Analytics workspace (name/region):

- Canary scope for Phase B:

## 2) Current WAD/LAD footprint (per node type / VMSS)

| Node type / VMSS | OS  | WAD/LAD installed? (Y/N/Unknown) | Current destinations (Storage/Other/Unknown) | Notes |
|------------------|-----|----------------------------------|----------------------------------------------|-------|
|                  |     |                                  |                                              |       |

## 3) Windows: Service Fabric events (Event Viewer / Windows Event Logs)

DCR collects Windows events via windowsEventLogs + XPath queries. [DCR samples](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples)

Example event (paste one sample record):

## 4) Linux: Service Fabric events (Syslog vs file logs)

- Syslog collection (facility + minimum level): [Collect syslog](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-syslog)

- File logs (text/JSON) via DCR logFiles + custom table/schema: [DCR samples](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples), [Collect JSON logs](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-log-json)

### 4.1 Syslog

| Facility (exact) | Minimum severity (Debug/Info/Notice/Warn/Error/Critical/Alert/Emergency) | Why needed | Notes |
|------------------|--------------------------------------------------------------------------|------------|-------|
|                  |                                                                          |            |       |

### 4.2 File logs

| File path / pattern (exact) | Format (text/json/other) | Rotation (daily/size/unknown) | Why needed | Notes |
|-----------------------------|--------------------------|-------------------------------|------------|-------|
|                             |                          |                               |            |       |

Example record (paste one line / JSON object):

## 5) Performance counters (Windows/Linux)

Perf counters via DCR performanceCounters. [Collect perf counters](https://outlook.office365.com/owa/?ItemID=AAMkADZjNTFjNTZiLWFkNTAtNDQwOS04NWFhLTQyM2M0NmMyOTg0MQBGAAAAAADxdGEF6q3OS4rjAjxrfVDUBwB1G834VyGwT5QOtVkK5HcPAAO2uE%2bhAAB1G834VyGwT5QOtVkK5HcPAAO2uXJrAAA%3d&exvsurl=1&viewmodel=ReadMessageItem)

## 6) Application / node logs (custom)

If you need application logs in text/JSON files, plan for custom tables and DCR logFiles. [DCR samples](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples), [Collect JSON logs](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-log-json)

## 7) Acceptance criteria (post‑migration)

Write 3--5 questions you expect to answer after migration (plain English): 1.

# Appendix: Service Fabric DCR sample JSON (Windows events → Log Analytics)

## Context

- Service Fabric events on Windows are fed into Windows Event Log (viewable in Event Viewer). The operational event reference also notes this and provides EventIds: <https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-generation-operational> [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-generation-operational)

- AMA collects Windows Event Logs via DCR "Windows events" data source; data lands in the Log Analytics **Event** table and can be filtered using XPath queries: <https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-windows-events> [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-windows-events)

- DCR JSON structure/samples for windowsEventLogs are available here: <https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples> [\[docs.azure.cn\]](https://docs.azure.cn/en-us/azure-monitor/data-collection/data-collection-rule-samples)

## Important note

These DCRs require the *exact* Windows Event Log channel names that contain Service Fabric events in your environment (from Event Viewer).

## DCR sample: Service Fabric Operational events (by EventId range)

- Use this when you primarily need platform/cluster operational events (node up/down, upgrades, etc.).

- Customer should adjust the XPath filter using the EventIds they care about (the operational reference lists EventIds).

```json
{
  "location": "<REGION>",
  "properties": {
    "dataSources": {
      "windowsEventLogs": [
        {
          "name": "sfOperationalEvents",
          "streams": ["Microsoft-Event"],
          "xPathQueries": [
            "Microsoft-ServiceFabric/Operational!*"
          ]
        }
      ]
    },
    "destinations": {
      "logAnalytics": [
        {
          "workspaceResourceId": "<LOG_ANALYTICS_WORKSPACE_RESOURCE_ID>",
          "name": "la"
        }
      ]
    },
    "dataFlows": [
      {
        "streams": ["Microsoft-Event"],
        "destinations": ["la"],
        "transformKql": "source",
        "outputStream": "Microsoft-Event"
      }
    ]
  }
}
```

# Appendix: Application Events, Reliable Actor and Stateful Service Events

- A documented solution for collecting a Application Events is to use EventSource

  - [Generate log events from a .NET app - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-how-to-diagnostics-log)

- Service Fabric Reliable Actors and Stateful Service emit diagnostic events using EventSource

  - [Actors diagnostics and monitoring - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-actors-diagnostics)

  - [Azure Service Fabric Stateful Reliable Services diagnostics - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-services-diagnostics)

### Service Events

- Skip if not using Microsoft.Diagnostics.EventFlow.Inputs.EventSource

- Rest of the section assumes Event source is configures as follows

| \[EventSource(Name = \"\<your-service-EventSource-name\>\")\] |
|---------------------------------------------------------------|

- Replace \"\<your-service-EventSource-name\>\" as appropriate

### Service Fabric Reliable Actor and Service events

- Skip if these are not being collected

- These are events emitted by Reliable Actor Runtime and Reliable Services StatefulServiceBase

### Configure EventFlow to route events to Azure Monitor Logs

- Skip if not collecting SF Reliable Actor and Service events or Service events is not using EventSource

- [Azure Service Fabric Event Aggregation with EventFlow - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-diagnostics-event-aggregation-eventflow) describes using EventFlow to send events to AppInsights.

- To target Azure Monitor Logs, use Azure Monitor Logs configs

<!-- -->

- *Following [Azure/diagnostics-eventflow: Microsoft Diagnostics EventFlow](https://github.com/Azure/diagnostics-eventflow?tab=readme-ov-file#azure-monitor-logs) Add package Microsoft.Diagnostics.EventFlow.Outputs.AzureMonitorLogs*

- *Change sample eventFlowConfig.json in the doc as follows*

- *Replace values in \<\> with environment specific values*

```json
{
  "inputs": [
    {
      "type": "EventSource",
      "sources": [
        // (skip if not collecting Actor runtime events)
        { "providerName": "Microsoft-ServiceFabric-Services" },

        // (skip if not collecting Stateful Service events)
        { "providerName": "Microsoft-ServiceFabric-Actors" },

        // (skip if not collecting Service events using EventSource)
        // (Replace with value used with EventSource in code)
        { "providerName": "<your-service-EventSource-name>" }
      ]
    }
  ],
  "filters": [
    {
      "type": "drop",
      "include": "Level == Verbose"
    }
  ],
  "outputs": [
    {
      "type": "AzureMonitorLogs",
      "workspaceId": "<workspace-GUID>",
      "workspaceKey": "<base-64-encoded workspace key>",
      "logTypeName": "<your-service-name>"
    }
  ],
  "schemaVersion": "2016-08-11"
}
```

## How to validate

A table named \<your-service-name\>\_CL should be created.

#### Service Events

```kusto
<your-service-name>_CL
| where ProviderName_s == "<your-service-EventSource-name>"
```

#### Reliable Actors Events

```kusto
<your-service-name>_CL
| where ProviderName_s == "Microsoft-ServiceFabric-Actors"
```

#### Reliable Service Events

```kusto
<your-service-name>_CL
| where ProviderName_s == "Microsoft-ServiceFabric-Services"
```

# Links appendix (Microsoft Learn)

## Migration & deprecation

- Migrate from WAD/LAD to AMA: [Migrate to Azure Monitor Agent from Azure Diagnostic extensions (WAD/LAD) - Azure Monitor \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-migration-wad-lad)

<!-- -->

- **Diagnostics extension overview (deprecation + migration context)**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/agents/diagnostics-extension-overview>

## **AMA + DCR**

- **Install / manage Azure Monitor Agent (AMA)**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage>

- **Create / edit Data Collection Rules (DCRs)**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-create-edit>

- **DCR JSON samples**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-rule-samples>

- **Monitor DCR data collection health**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/data-collection-monitor>

## **Data sources (via AMA)**

- **Collect Syslog with AMA**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-syslog>

- **Collect performance counters with AMA**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-performance>

- **Collect JSON logs with AMA**  
  <https://learn.microsoft.com/en-us/azure/azure-monitor/vm/data-collection-log-json>

## **Service Fabric (events & channels)**

- **Service Fabric diagnostics & event collection (EventSource / channels)**  
  [Monitor Azure Service Fabric - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/monitor-service-fabric)

- **Reliable Actors Events (Actors event source)**  
  [Actors diagnostics and monitoring - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-actors-diagnostics)

- **Stateful Reliable Service Events (Services event source)  
  **[Azure ServiceFabric diagnostics and monitoring - Azure Service Fabric \| Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-serviceremoting-diagnostics)
