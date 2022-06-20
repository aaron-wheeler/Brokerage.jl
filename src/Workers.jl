module Workers
# for concurrency
# right now the pickAlbumToListen function is the only potentially costly operation, so its only used there

# unbuffered Channel of tasks 
const WORK_QUEUE = Channel{Task}(0)

# main thread one will put tasks onto work queue
macro async(thunk)
    esc(quote
        tsk = @task $thunk
        tsk.storage = current_task().storage
        put!(Workers.WORK_QUEUE, tsk)
        tsk
    end)
end

# workers threads all pulling tasks off work queue
function init()
    tids = Threads.nthreads() == 1 ? (1:1) : 2:Threads.nthreads()
    Threads.@threads for tid in 1:Threads.nthreads()
        if tid in tids
            Base.@async begin
                for task in WORK_QUEUE
                    schedule(task)
                    wait(task)
                end
            end
        end
    end
    return
end

end # module