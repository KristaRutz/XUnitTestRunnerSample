using System;
using Xunit;

namespace XUnitTestProjectCore
{
    public class UnitTest1
    {
        [Fact]
        public void CoreTestOfTruth()
        {
            Assert.True(true);
        }

        [Fact]
        public void CoreTestOfFalsehood()
        {
            Assert.True(false);
        }

        [Fact]
        public void CoreTest()
        {
            Assert.True(true);
        }
    }
}
