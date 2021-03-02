using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.Azure.Geneva.Synthetics.Contracts;
using Microsoft.Azure.Geneva.Synthetics.Logging.OneDS;
using Microsoft.Extensions.Logging;

namespace GenevaLibrary
{
    public class SimpleSyntheticJob : ISyntheticJob, IDisposable 
    {        
        private TelemetryClient TelemetryClient { get; }

        private ISyntheticsEnvironment Environment { get; }

        private Metric TestMetric { get; }

        ILogger logger;

        public SimpleSyntheticJob(ISyntheticsEnvironment environment)
        {
            Environment = environment ?? throw new ArgumentNullException(nameof(environment));
            TelemetryClient = SyntheticsTelemetryClientCache.Instance.GetOrAdd(environment, metricNamespace: "GenevaSyntheticsSamples");
            TestMetric = TelemetryClient.GetMetric(metricId: "TestMetric", dimension1Name: "TestDimension");
            ILoggerFactory loggerFactory = new LoggerFactory();
            logger = loggerFactory.CreateLogger<SimpleSyntheticJob>();

        }

        public async Task RunAsync(IReadOnlyDictionary<string, string> parameters)
        {
            Console.WriteLine("**********************************************************************");
            Console.WriteLine("**********************************************************************");

            logger.LogInformation("Log entry from outside using statement");
            // This will set the trace ID on the operation_Id column in all logs emitted with the App Insights / OneDS SDK within this using block.
            // The ID is stored on System.Diagnostics.Activity.Current and will also apply to other TelemetryClient objects used within this block.
            // It also emits a special message to the RequestTelemetry table for Distributed Tracing integration.
            using (var operation = TelemetryClient.StartSyntheticTransaction(parameters))
            {
                logger.LogInformation("Log entry from inside using statement");

                TelemetryClient.TrackTrace("Hello from Ev2!", SeverityLevel.Information);

                // Emit metrics for alerting through Geneva Monitors.
                TestMetric.TrackValue(1, "DimensionValue");

                Console.WriteLine("-------------------------------------------------------");

                // Run custom test runner - with hard coded test .dll
                TestRunner.Run(@"C:\Users\v-kristarutz\source\repos\TestRunnerSample\XUnitTestProject\bin\Debug\net472\XUnitTestProject.dll", TelemetryClient);
                Console.WriteLine("-------------------------------------------------------");
                

                // Success property is set to false by default. Should set to true at end of iteration if all went well.
                // This only affects the RequestTelemetry event and has no impact on the Synthetics platform. You cannot alert on this.
                operation.Telemetry.Success = true;
            }
        }

        public void Dispose()
        {
            // IMPORTANT: Necessary to flush all clients before process exits or events may be lost.
            //            All clients created by SyntheticsTelemetryClientCache.Instance are covered by the below method.
            //            If you create custom TelemetryClient objects in your code, make sure to flush them as well.
            //            You must implement IDisposable in your job for this Dispose method to be called.
            //            Just copying the method into your job without implementing IDisposable will not work!
            SyntheticsTelemetryClientCache.Instance.FlushAll();
        }
    }
}

