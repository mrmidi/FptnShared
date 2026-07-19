/*=============================================================================
Copyright (c) 2026 Aleksandr Shabelnikov

Distributed under the MIT License (https://opensource.org/licenses/MIT)
=============================================================================*/

import Foundation
#if !CLI_BUILD
import FptnSharedCore
import FptnServerSelection
import FptnSharedTestSupport
#endif

struct ScenarioServer: Codable {
    let id: String
    let delay_ms: Int
    let outcome: String
}

struct Scenario: Codable {
    let servers: [ScenarioServer]
    let maximum_active: Int?
    let overall_timeout_ms: Int?
}

func printUsage() {
    print("""
    FPTN Auto Server Selector CLI Tool
    
    Usage:
      fptn-selector simulate --scenario <path_to_json>
      fptn-selector race --config <path_to_config_txt> [--concurrency <limit>]
    
    Example:
      fptn-selector simulate --scenario scenarios/test_scenario.json
      fptn-selector race --config temp_config.txt --concurrency 4
    """)
}

func runSimulation(scenarioPath: String) async {
    let url = URL(fileURLWithPath: scenarioPath)
    guard let data = try? Data(contentsOf: url) else {
        print("Error: Failed to read scenario file at \(scenarioPath)")
        exit(1)
    }
    
    let decoder = JSONDecoder()
    guard let scenario = try? decoder.decode(Scenario.self, from: data) else {
        print("Error: Failed to parse JSON scenario file. Verify schema.")
        exit(1)
    }
    
    print("Loaded scenario with \(scenario.servers.count) servers.")
    
    // Build candidate list and map simulated outcomes
    var candidates: [VPNServer] = []
    var simulatedOutcomes: [String: SimulatedOutcome] = [:]
    
    for s in scenario.servers {
        let server = VPNServer(
            name: s.id,
            host: "\(s.id).fptn.org",
            port: 443,
            md5Fingerprint: "fingerprint_\(s.id)"
        )
        candidates.append(server)
        
        simulatedOutcomes[s.id] = SimulatedOutcome(
            delayMs: s.delay_ms,
            status: s.outcome
        )
    }
    
    let fakeProbe = FakeServerBootstrapProbe(simulatedOutcomes: simulatedOutcomes)
    let race = SlidingWindowRace()
    
    let credentials = Credentials(username: "simulated_user", password: "simulated_password")
    let context = ProbeContext(
        networkClass: .wifi,
        sni: "music.yandex.ru",
        censorshipStrategy: .sniRealityChrome147,
        ipv6Available: false,
        tokenConfigurationID: "test_config_digest"
    )
    
    let maxActive = scenario.maximum_active ?? 4
    let overallTimeout = Duration.milliseconds(scenario.overall_timeout_ms ?? 30000)
    
    print("\n--- Starting Connection Race Simulation ---")
    print("Concurrency Limit: \(maxActive)")
    print("Overall Timeout:   \(scenario.overall_timeout_ms ?? 30000) ms")
    
    let startTime = Date()
    let result = await race.run(
        candidates: candidates,
        credentials: credentials,
        context: context,
        limit: maxActive,
        timeout: .seconds(5),
        overallTimeout: overallTimeout,
        probe: fakeProbe
    )
    let endTime = Date()
    let totalElapsedMs = Int(endTime.timeIntervalSince(startTime) * 1000)
    
    printDiagnostics(result: result, totalElapsedMs: totalElapsedMs)
}

#if CLI_BUILD
func runRealRace(configPath: String, concurrency: Int) async {
    let url = URL(fileURLWithPath: configPath)
    guard let dataStr = try? String(contentsOf: url, encoding: .utf8) else {
        print("Error: Failed to read config file at \(configPath)")
        exit(1)
    }
    
    let lines = dataStr.components(separatedBy: .newlines)
    guard lines.count >= 4 else {
        print("Error: Invalid config file format.")
        exit(1)
    }
    
    let username = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let password = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
    let strategyStr = lines[2].trimmingCharacters(in: .whitespacesAndNewlines)
    let sni = lines[3].trimmingCharacters(in: .whitespacesAndNewlines)
    
    let strategy = CensorshipStrategy(storedValue: strategyStr)
    
    print("Loaded configuration:")
    print("  Username: \(username)")
    print("  Strategy: \(strategy.displayName) (\(strategy.rawValue))")
    print("  SNI:      \(sni)")
    
    var candidates: [VPNServer] = []
    for line in lines[4...] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        
        let parts = trimmed.components(separatedBy: "|")
        guard parts.count >= 4 else { continue }
        
        let server = VPNServer(
            name: parts[0],
            host: parts[1],
            port: Int(parts[2]) ?? 443,
            md5Fingerprint: parts[3]
        )
        candidates.append(server)
    }
    
    print("Loaded \(candidates.count) servers from configuration.")
    
    let nativeProbe = NativeServerBootstrapProbe()
    let race = SlidingWindowRace()
    
    let credentials = Credentials(username: username, password: password)
    let context = ProbeContext(
        networkClass: .wifi,
        sni: sni,
        censorshipStrategy: strategy,
        ipv6Available: false,
        tokenConfigurationID: "token_config_digest"
    )
    
    print("\n--- Starting Real Native Connection Race ---")
    print("Concurrency Limit: \(concurrency)")
    print("Candidates Count:  \(candidates.count)")
    
    let startTime = Date()
    let result = await race.run(
        candidates: candidates,
        credentials: credentials,
        context: context,
        limit: concurrency,
        timeout: .seconds(5),
        overallTimeout: .seconds(30),
        probe: nativeProbe
    )
    let endTime = Date()
    let totalElapsedMs = Int(endTime.timeIntervalSince(startTime) * 1000)
    
    printDiagnostics(result: result, totalElapsedMs: totalElapsedMs)
}
#endif

func printDiagnostics(result: AutoSelectionResult, totalElapsedMs: Int) {
    print("\n==================================================")
    print("FPTN Server Selection Diagnostic Report")
    print("==================================================")
    
    switch result {
    case .success(let bootstrap):
        print("Winner Found:")
        print("  Server:        \(bootstrap.server.name)")
        print("  Queue Position: \(bootstrap.metrics.queuePosition)")
        print("  Latency:        \(bootstrap.metrics.totalMs) ms")
        print("  Access Token:   \(bootstrap.accessToken.prefix(25))...")
        print("  DNS IPv4:       \(bootstrap.dnsIPv4)")
        if let v6 = bootstrap.dnsIPv6 {
            print("  DNS IPv6:       \(v6)")
        }
        
    case .allCandidatesFailed(let summary):
        print("Winner Found:    NONE (All candidates failed)")
        print("Failure Summary:")
        print("  Attempted:     \(summary.attemptedCount) servers")
        print("  Failures:      \(summary.failuresByKind)")
        if let rep = summary.representativeFailure {
            print("  Example Error: \(rep.kind.rawValue) on \(rep.server.name)")
            if let diag = rep.safeDiagnostic {
                print("  Detail:        \(diag)")
            }
        }
        
    case .cancelled:
        print("Winner Found:    NONE (Race was cancelled / timed out)")
        
    default:
        print("Winner Found:    NONE (Unexpected outcome)")
    }
    
    print("\nRace Metrics:")
    print("  Total Elapsed: \(totalElapsedMs) ms")
    print("==================================================")
}

// Program Entry Point
let args = CommandLine.arguments

guard args.count >= 4 else {
    printUsage()
    exit(1)
}

let command = args[1]

if command == "simulate" {
    let option = args[2]
    let scenarioPath = args[3]
    if option == "--scenario" {
        await runSimulation(scenarioPath: scenarioPath)
    } else {
        printUsage()
        exit(1)
    }
} else if command == "race" {
    #if CLI_BUILD
    let option = args[2]
    let configPath = args[3]
    
    var concurrency = 4
    if args.count >= 6 && args[4] == "--concurrency" {
        concurrency = Int(args[5]) ?? 4
    }
    
    if option == "--config" {
        await runRealRace(configPath: configPath, concurrency: concurrency)
    } else {
        printUsage()
        exit(1)
    }
    #else
    print("Error: The 'race' command requires C++ Interop and is not supported in the standard build.")
    exit(1)
    #endif
} else {
    printUsage()
    exit(1)
}
