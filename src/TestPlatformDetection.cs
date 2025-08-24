using System;
using System.Runtime.InteropServices;
using BookStore.Infrastructure.Services;

class Program
{
    static void Main()
    {
        Console.WriteLine("Testing Platform Detection Service...");
        
        var platformService = new PlatformDetectionService();
        
        Console.WriteLine($"Current Platform: {platformService.GetCurrentPlatform()}");
        Console.WriteLine($"Is Windows: {platformService.IsWindows()}");
        Console.WriteLine($"Is Linux: {platformService.IsLinux()}");
        
        // Test consistency
        var platform1 = platformService.GetCurrentPlatform();
        var platform2 = platformService.GetCurrentPlatform();
        Console.WriteLine($"Platform detection is consistent: {platform1 == platform2}");
        
        // Test against RuntimeInformation directly
        var directWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
        var directLinux = RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
        
        Console.WriteLine($"Service Windows matches RuntimeInformation: {platformService.IsWindows() == directWindows}");
        Console.WriteLine($"Service Linux matches RuntimeInformation: {platformService.IsLinux() == directLinux}");
        
        Console.WriteLine("Platform Detection Service test completed successfully!");
    }
}