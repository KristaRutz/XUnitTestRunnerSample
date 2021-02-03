using Xunit;

namespace XUnitTestProject
{
    public class UnitTest1
    {
        [Fact]
        public void TestOfTruth()
        {
            Assert.True(true);
        }

        [Fact]
        public void TestOfFalsehood()
        {
            Assert.True(false);
        }
    }
}
