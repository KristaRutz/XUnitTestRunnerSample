# XUnitTestRunnerSample

The goal here is to practice running tests programmatically.
1. Make a test project
2. Write a hello world unit test
3. Discover the tests (via code)
4. Run the tests

## Technologies
- Visual Studio 2019
- xUnit
- Specifically, xUnit.Runners for AssemblyRunner class

## Installation
- clone the repo, restore NuGet packages, and build files
- locate full path for XUnitTestProject.dll file in the Debug folder after building
- pass this as a debug argument to the Program.cs file:
  - right click TestRunnerSample.csproj within VS Solution Explorer > Properties > Debug > Command line arguments
  - paste the full path of the .dll file as a string (in quotes)
  - add class name to filter tests if wanted, separated by commas
- save & run
