## 临时解决方案：在现有文件中添加代码

由于项目使用了文件系统同步组，我们可以先将DanmuMemoryMonitor的代码添加到现有文件中：

### 选项1：添加到 VideoDanmuProvider.swift 文件末尾

在 `VideoDanmuProvider.swift` 文件的最后添加以下代码：

```swift
// MARK: - Memory Monitoring

protocol DanmuMemoryMonitorDelegate: AnyObject {
    func didReceiveMemoryWarning(availableMemory: UInt64, memoryPressure: DanmuMemoryPressure)
    func shouldOptimizePerformance(cpuUsage: Double, frameRate: Double)
}

enum DanmuMemoryPressure {
    case normal
    case moderate
    case critical
}

class DanmuMemoryMonitor {
    static let shared = DanmuMemoryMonitor()
    
    weak var delegate: DanmuMemoryMonitorDelegate?
    
    private var monitorTimer: Timer?
    private var lastTimestamp = CACurrentMediaTime()
    private var frameCount = 0
    private var currentFPS: Double = 60.0
    
    private var memoryPressureHistory: [UInt64] = []
    private let maxHistoryCount = 10
    
    private var isMonitoring = false
    
    private init() {}
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkMemoryStatus()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        monitorTimer?.invalidate()
        monitorTimer = nil
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func didReceiveMemoryWarning() {
        let availableMemory = getAvailableMemory()
        let pressure = calculateMemoryPressure(availableMemory)
        delegate?.didReceiveMemoryWarning(availableMemory: availableMemory, memoryPressure: pressure)
    }
    
    private func checkMemoryStatus() {
        let availableMemory = getAvailableMemory()
        updateMemoryHistory(availableMemory)
        
        let pressure = calculateMemoryPressure(availableMemory)
        if pressure != .normal {
            delegate?.didReceiveMemoryWarning(availableMemory: availableMemory, memoryPressure: pressure)
        }
        
        let cpuUsage = getCPUUsage()
        if cpuUsage > 80.0 || currentFPS < 30.0 {
            delegate?.shouldOptimizePerformance(cpuUsage: cpuUsage, frameRate: currentFPS)
        }
    }
    
    func updateFrameRate() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastTimestamp
        
        if deltaTime >= 1.0 {
            currentFPS = Double(frameCount) / deltaTime
            frameCount = 0
            lastTimestamp = currentTime
        }
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.user_time.seconds + info.system_time.seconds)
        }
        
        return 0.0
    }
    
    private func updateMemoryHistory(_ memory: UInt64) {
        memoryPressureHistory.append(memory)
        if memoryPressureHistory.count > maxHistoryCount {
            memoryPressureHistory.removeFirst()
        }
    }
    
    private func calculateMemoryPressure(_ currentMemory: UInt64) -> DanmuMemoryPressure {
        let mb = currentMemory / (1024 * 1024)
        
        switch mb {
        case 0..<200:
            return .critical
        case 200..<500:
            return .moderate
        default:
            return .normal
        }
    }
    
    func getCurrentMemoryUsage() -> (resident: UInt64, virtual: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return (resident: info.resident_size, virtual: info.virtual_size)
        }
        
        return (resident: 0, virtual: 0)
    }
    
    func getMemoryPressureLevel() -> DanmuMemoryPressure {
        let availableMemory = getAvailableMemory()
        return calculateMemoryPressure(availableMemory)
    }
}
```

这样就可以立即测试所有功能了！