  Under-Specified                                                                                                                         
                                                                                                                                          
  1. Reviewer Behavior                                                                                                                    
  - Does it only run tests, or also linting/static analysis/code review?                                                                  
  - What happens when rebase against main has conflicts?                                                                                  
  - What's the merge commit message format?                                                                                               
  - Does it notify anyone on success/failure?                                                                                             
                                                                                                                                          
  2. Assigner Mechanics                                                                                                                   
  - What triggers it? Polling on an interval? Event-driven (bead status change)?                                                          
  - Is there a concurrency limit (max simultaneous Doers)?                                                                                
  - README says Assigner creates the branch - but on first attempt only? Or does it check if branch exists?                               
                                                                                                                                          
  3. The "Dumb" Distinction                                                                                                               
  - README calls Assigner and Reviewer "dumb" - does that mean they're simple scripts/cron jobs, or still LLM-powered but with narrow     
  scope?                                                                                                                                  
  - If they're not LLMs, what are they? Shell scripts? A small daemon?                                                                    
                                                                                                                                          
  4. Runtime Model                                                                                                                        
  - Where does this run? Local CLI? Server? GitHub Actions?                                                                               
  - How are Doer sessions spawned? Subprocesses? Containers?                                                                              
  - How is state (current Doer name index, etc.) persisted?                                                                               
                                                                                                                                          
  5. Observability                                                                                                                        
  - How does the human monitor progress? Dashboard? Terminal output? Notifications?                                                       
  - How do you know when something is stuck or escalated?                                                                                 
                                                                                                                                          
  6. Failure Modes                                                                                                                        
  - What if a Doer crashes without writing its log?                                                                                       
  - What if the Assigner crashes mid-assignment (bead locked but no Doer)?                                                                
  - Stale locks / timeouts? 
