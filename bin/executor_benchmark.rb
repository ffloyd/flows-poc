#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'benchmark/ips'
require 'dry/transaction'
require 'flows'

#
# NativeNaive realization
#

# Steps' methods realization
module Steps
  def step1(data)
    data == :slow ? rand(100).to_f : rand(100)
  end

  def step2(data)
    data * 2
  end

  def cond_step(data)
    data.is_a?(Float) ? [:slow, data] : [:fast, data]
  end

  def fast_step(data)
    data.to_s
  end

  def slow_step(data)
    data.to_s * 10_000
  end
end

# NativeNaive - is a very simple useless flow in form of PORO
class NativeNaive
  include Steps

  def call(data)
    data = step1(data)
    data = step2(data)
    signal, data = cond_step(data)

    data = case signal
           when :fast then fast_step(data)
           when :slow then slow_step(data)
           end

    [:ok, data]
  end
end

# Precreated instance for possible speed-up
native_naive = NativeNaive.new

#
# Dry::Transaction realization
#

# Dry::Transaction realization without Either usage, fast path
class FastTrWoEither
  include Steps
  include Dry::Transaction

  map :step1
  map :step2
  map :fast_step
end

fast_tr_wo_either = FastTrWoEither.new

# Dry::Transaction realization without Either usage, slow path
class SlowTrWoEither
  include Steps
  include Dry::Transaction

  map :step1
  map :step2
  map :slow_step
end

slow_tr_wo_either = FastTrWoEither.new

#
# Raw schema realizations
#

step1_proc     = proc { |x| x == :slow ? 100.0 : 100 }
step2_proc     = proc { |x| x * 2 }
cond_step_proc = proc { |x| x.is_a?(Float) ? [:slow, x] : [:fast, x] }
fast_step_proc = proc { |x| x.to_s }
slow_step_proc = proc { |x| x.to_s * 10_000 }

proc_schema = [
  :step1,
  {
    step1: [
      step1_proc,
      :step2
    ],
    step2: [
      step2_proc,
      :cond_step
    ],
    cond_step: [
      cond_step_proc,
      {
        fast: :fast_step,
        slow: :slow_step
      }
    ],
    fast_step: [
      fast_step_proc,
      :exit
    ],
    slow_step: [
      slow_step_proc,
      :exit
    ],
    exit: :ok
  }
]

step1_lam      = ->(x) { x == :slow ? 100.0 : 100 }
step2_lam      = ->(x) { x * 2 }
cond_step_lam  = ->(x) { x.is_a?(Float) ? [:slow, x] : [:fast, x] }
fast_step_lam  = ->(x) { x.to_s }
slow_step_lam  = ->(x) { x.to_s * 10_000 }

lambda_schema = [
  :step1,
  {
    step1: [
      step1_lam,
      :step2
    ],
    step2: [
      step2_lam,
      :cond_step
    ],
    cond_step: [
      cond_step_lam,
      {
        fast: :fast_step,
        slow: :slow_step
      }
    ],
    fast_step: [
      fast_step_lam,
      :exit
    ],
    slow_step: [
      slow_step_lam,
      :exit
    ],
    exit: :ok
  }
]

method_schema = [
  :step1,
  {
    step1: [
      native_naive.method(:step1),
      :step2
    ],
    step2: [
      native_naive.method(:step2),
      :cond_step
    ],
    cond_step: [
      native_naive.method(:cond_step),
      {
        fast: :fast_step,
        slow: :slow_step
      }
    ],
    fast_step: [
      native_naive.method(:fast_step),
      :exit
    ],
    slow_step: [
      native_naive.method(:slow_step),
      :exit
    ],
    exit: :ok
  }
]

#
# Benchmarking
#

def puts_header(header)
  header_str = '####### ' + header + ' #######' + "\n"
  around = '#' * header_str.size

  puts
  puts around, header_str, around
  puts
end

def puts_subheader(subheader)
  puts
  puts '####### ' + subheader
  puts
end

benchmark_with_arg = lambda do |arg|
  puts_subheader 'Naive PORO realization'

  Benchmark.ips do |x|
    x.config(warmup: 2, time: 5)

    x.report('NativeNaive [prepared]')   { native_naive.call(arg) }
    x.report('NativeNaive [recreating]') { NativeNaive.new.call(arg) }
  end

  puts_subheader 'Dry::Transaction without using Either'

  Benchmark.ips do |x|
    x.config(warmup: 2, time: 5)

    if arg == :slow
      x.report('Dry::Transaction [prepared]')   { slow_tr_wo_either.call(arg) }
      x.report('Dry::Transaction [recreating]') { SlowTrWoEither.new.call(arg) }
    else
      x.report('Dry::Transaction [prepared]')   { fast_tr_wo_either.call(arg) }
      x.report('Dry::Transaction [recreating]') { FastTrWoEither.new.call(arg) }
    end
  end

  puts_subheader 'Flows::Executor executing a schema'

  Benchmark.ips do |x|
    x.config(warmup: 2, time: 5)

    x.report('Flows::Executor [proc]')   { Flows::Executor.call(proc_schema,   arg) }
    x.report('Flows::Executor [lambda]') { Flows::Executor.call(lambda_schema, arg) }
    x.report('Flows::Executor [method]') { Flows::Executor.call(method_schema, arg) }
  end
end

puts_header 'Benchmarking infrastructure (no significant busuness logic involved)'
benchmark_with_arg.call(:fast)

puts_header 'Benchmarking "real case" (some relatively expensive logic involved)'
benchmark_with_arg.call(:slow)
