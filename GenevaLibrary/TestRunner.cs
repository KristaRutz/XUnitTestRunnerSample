using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Xunit.Runners;
using Microsoft.Extensions.Logging;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using System.Net.Mime;

namespace GenevaLibrary
{
    public class TestRunner
    {
        // We use consoleLock because messages can arrive in parallel, so we want to make sure we get
        // consistent console output.
        static object consoleLock = new object();

        static TelemetryClient telemetryClient;

        // Use an event to know when we're done
        static ManualResetEvent finished = new ManualResetEvent(false);

        // Start out assuming success; we'll set this to 1 if we get a failed test
        static int result = 0;

        public static void Run(string testAssembly, TelemetryClient TelemetryClient, string typeName = null)
        {
            telemetryClient = TelemetryClient;
            Console.WriteLine("Running in TestRunner.Run()");
            using (var runner = AssemblyRunner.WithoutAppDomain(testAssembly))
            {
                runner.OnDiscoveryComplete = OnDiscoveryComplete;
                runner.OnExecutionComplete = OnExecutionComplete;
                runner.OnTestStarting = OnTestStarting;
                runner.OnTestFailed = OnTestFailed;
                runner.OnTestSkipped = OnTestSkipped;
                runner.OnTestPassed = OnTestPassed;
                runner.OnDiagnosticMessage = OnDiagnosticMessage;

                telemetryClient.TrackTrace("Discovering...", SeverityLevel.Information);
                runner.Start(typeName);

                finished.WaitOne();
                finished.Dispose();

                //return result;
            }
        }

        private static void OnDiagnosticMessage(DiagnosticMessageInfo info)
        {
            lock (consoleLock)
            {
                telemetryClient.TrackTrace(info.Message, SeverityLevel.Information);
            }
        }

        static void OnDiscoveryComplete(DiscoveryCompleteInfo info)
        {
            lock (consoleLock)
                telemetryClient.TrackTrace($"Running {info.TestCasesToRun} of {info.TestCasesDiscovered} tests...", SeverityLevel.Information);
        }

        static void OnExecutionComplete(ExecutionCompleteInfo info)
        {
            lock (consoleLock)
                telemetryClient.TrackTrace($"Finished: {info.TotalTests} tests in {Math.Round(info.ExecutionTime, 3)}s ({info.TestsFailed} failed, {info.TestsSkipped} skipped)", SeverityLevel.Information);

            finished.Set();
        }
        static void OnTestStarting(TestStartingInfo info)
        {
            lock (consoleLock)
            {
                telemetryClient.TrackTrace($"[STARTING TEST] {info.TestDisplayName}", SeverityLevel.Information);
            }
        }

        static void OnTestFailed(TestFailedInfo info)
        {
            lock (consoleLock)
            {
                telemetryClient.TrackTrace($"[FAIL] {info.TestDisplayName}: {info.ExceptionMessage}", SeverityLevel.Warning);
                if (info.ExceptionStackTrace != null)
                    telemetryClient.TrackTrace(info.ExceptionStackTrace, SeverityLevel.Information);
            }

            result = 1;
        }

        static void OnTestSkipped(TestSkippedInfo info)
        {
            lock (consoleLock)
            {
                telemetryClient.TrackTrace($"[SKIP] { info.TestDisplayName}: { info.SkipReason}", SeverityLevel.Warning);
            }
        }

        private static void OnTestPassed(TestPassedInfo info)
        {
            lock (consoleLock)
            {
                telemetryClient.TrackTrace($"[PASS] {info.TestDisplayName}", SeverityLevel.Information);
                if (info.Output != "") telemetryClient.TrackTrace(info.Output, SeverityLevel.Information);
            }
        }
    }
}
