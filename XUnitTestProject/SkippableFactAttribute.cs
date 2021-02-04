using Xunit;
using Xunit.Sdk;

namespace XUnitTestProject
    
{
    [XunitTestCaseDiscoverer("DynamicSkipExample.XunitExtensions.SkippableFactDiscoverer", "DynamicSkipExample")]
    public class SkippableFactAttribute : FactAttribute { }
}
