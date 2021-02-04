using System;
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

        [Fact]
        public void Test3()
        {
            Assert.True(true);
        }
    }
    public class DynamicSkipExampleFacts
    {
        [Fact]
        public void NonSkippableFact() { }

        [SkippableFact]
        public void Passing() { }

        [SkippableFact(Skip = "I never feel like it")]
        public void StaticallySkipped() { }

        [SkippableFact]
        public void DynamicallySkipped()
        {
            // You could hide this behind something like "Assert.Skip", by bring in the assertion
            // library as source and extending the Assert class.
            throw new Exception("I don't feel like it right now, ask again later");
        }

        [SkippableFact]
        public void Failing()
        {
            Assert.True(false);
        }
    }
}
