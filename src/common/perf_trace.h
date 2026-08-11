// SPDX-FileCopyrightText: Copyright 2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <mutex>

#include "common/path_util.h"
#include "common/types.h"

namespace Common::PerfTrace {

struct CounterSnapshot {
    u64 total_us{};
    u64 max_us{};
    u64 count{};
};

class Counter {
public:
    void Add(u64 duration_us) noexcept {
        total_us.fetch_add(duration_us, std::memory_order_relaxed);
        count.fetch_add(1, std::memory_order_relaxed);

        u64 current = max_us.load(std::memory_order_relaxed);
        while (current < duration_us &&
               !max_us.compare_exchange_weak(current, duration_us, std::memory_order_relaxed,
                                             std::memory_order_relaxed)) {
        }
    }

    CounterSnapshot Consume() noexcept {
        return {
            .total_us = total_us.exchange(0, std::memory_order_relaxed),
            .max_us = max_us.exchange(0, std::memory_order_relaxed),
            .count = count.exchange(0, std::memory_order_relaxed),
        };
    }

private:
    std::atomic<u64> total_us{};
    std::atomic<u64> max_us{};
    std::atomic<u64> count{};
};

inline Counter queue_submit;
inline Counter gpu_wait;
inline Counter swapchain_acquire;
inline Counter swapchain_present;
inline Counter shader_module_create;

inline u64 ToMicroseconds(std::chrono::steady_clock::duration duration) noexcept {
    return static_cast<u64>(
        std::chrono::duration_cast<std::chrono::microseconds>(duration).count());
}

inline void RecordQueueSubmit(std::chrono::steady_clock::duration duration) noexcept {
    queue_submit.Add(ToMicroseconds(duration));
}

inline void RecordGpuWait(std::chrono::steady_clock::duration duration) noexcept {
    gpu_wait.Add(ToMicroseconds(duration));
}

inline void RecordSwapchainAcquire(std::chrono::steady_clock::duration duration) noexcept {
    swapchain_acquire.Add(ToMicroseconds(duration));
}

inline void RecordSwapchainPresent(std::chrono::steady_clock::duration duration) noexcept {
    swapchain_present.Add(ToMicroseconds(duration));
}

inline void RecordShaderModuleCreate(std::chrono::steady_clock::duration duration) noexcept {
    shader_module_create.Add(ToMicroseconds(duration));
}

struct TraceState {
    static constexpr size_t FileBufferSize = 1 << 20;

    std::mutex mutex;
    std::array<char, FileBufferSize> file_buffer{};
    std::ofstream file;
    std::chrono::steady_clock::time_point last_present{};
    u64 frame{};
};

inline TraceState& GetState() {
    static TraceState state;
    return state;
}

inline void FramePresented() {
    using Clock = std::chrono::steady_clock;

    const auto now = Clock::now();
    auto& state = GetState();
    std::scoped_lock lock{state.mutex};

    const u64 interval_us = state.last_present.time_since_epoch().count() == 0
                                ? 0
                                : ToMicroseconds(now - state.last_present);

    const CounterSnapshot submit = queue_submit.Consume();
    const CounterSnapshot wait = gpu_wait.Consume();
    const CounterSnapshot acquire = swapchain_acquire.Consume();
    const CounterSnapshot present = swapchain_present.Consume();
    const CounterSnapshot shader = shader_module_create.Consume();

    if (!state.file.is_open()) {
        const auto& log_dir = FS::GetUserPath(FS::PathType::LogDir);
        std::error_code ec;
        std::filesystem::create_directories(log_dir, ec);
        state.file.rdbuf()->pubsetbuf(state.file_buffer.data(), state.file_buffer.size());
        state.file.open(log_dir / "perf_trace.csv", std::ios::out | std::ios::trunc);
        if (state.file.is_open()) {
            state.file
                << "frame,host_interval_ms,queue_submit_total_ms,queue_submit_max_ms,"
                   "queue_submit_count,gpu_wait_total_ms,gpu_wait_max_ms,gpu_wait_count,"
                   "swapchain_acquire_total_ms,swapchain_acquire_max_ms,swapchain_acquire_count,"
                   "swapchain_present_total_ms,swapchain_present_max_ms,swapchain_present_count,"
                   "shader_module_total_ms,shader_module_max_ms,shader_module_count\n";
        }
    }

    if (state.file.is_open()) {
        constexpr double UsToMs = 1.0 / 1000.0;
        state.file << state.frame << ',' << interval_us * UsToMs << ','
                   << submit.total_us * UsToMs << ',' << submit.max_us * UsToMs << ','
                   << submit.count << ',' << wait.total_us * UsToMs << ','
                   << wait.max_us * UsToMs << ',' << wait.count << ','
                   << acquire.total_us * UsToMs << ',' << acquire.max_us * UsToMs << ','
                   << acquire.count << ',' << present.total_us * UsToMs << ','
                   << present.max_us * UsToMs << ',' << present.count << ','
                   << shader.total_us * UsToMs << ',' << shader.max_us * UsToMs << ','
                   << shader.count << '\n';
    }

    ++state.frame;
    // Exclude the trace bookkeeping itself from the next host frame interval.
    state.last_present = Clock::now();
}

} // namespace Common::PerfTrace
