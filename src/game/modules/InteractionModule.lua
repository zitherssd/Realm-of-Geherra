local InteractionModule = {}

InteractionModule.handlers = {}

function InteractionModule.register(name, handler)
  InteractionModule.handlers[name] = handler
end

function InteractionModule.trigger(actor, target, interactionType)
  local handler = InteractionModule.handlers[interactionType]
  if handler and target.interactions then
    for _, v in ipairs(target.interactions) do
      if v == interactionType then
        return handler(actor, target)
      end
    end
  end
end

return InteractionModule 