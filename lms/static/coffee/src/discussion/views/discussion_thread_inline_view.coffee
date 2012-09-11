if Backbone?
  class @DiscussionThreadInlineView extends DiscussionContentView
    expanded = false
    events:
      "click .discussion-vote": "toggleVote"
      "click .action-follow": "toggleFollowing"
      "click .discussion-submit-post": "submitComment"
      "click .action-edit": "edit"
      "click .action-delete": "delete"
      "click .action-openclose": "toggleClosed"
      "click .expand-post": "expandPost"
      "click .collapse-post": "collapsePost"

    template: -> DiscussionUtil.getTemplate("_inline_thread")

    initLocal: ->
      @$local = @$el.children(".discussion-article").children(".local")
      @$delegateElement = @$local

    initialize: ->
      super()
      @model.on "change", @updateModelDetails

    render: ->
      if not @model.has('abbreviatedBody')
        @abbreviateBody()
      params = $.extend(@model.toJSON(),{expanded: @expanded})
      if not @model.get('anonymous')
        params = $.extend(params, user:{username: @model.username, user_url: @model.user_url})
      @$el.html(Mustache.render(@template(), params))
      @initLocal()
      @delegateEvents()
      @renderDogear()
      @renderVoted()
      @renderAttrs()
      @$("span.timeago").timeago()
      @convertMath()
      if @expanded
        @makeWmdEditor "reply-body"
        @renderResponses()
      @

    renderDogear: ->
      if window.user.following(@model)
        @$(".dogear").addClass("is-followed")

    renderVoted: =>
      if window.user.voted(@model)
        @$("[data-role=discussion-vote]").addClass("is-cast")
      else
        @$("[data-role=discussion-vote]").removeClass("is-cast")

    updateModelDetails: =>
      @renderVoted()
      @$("[data-role=discussion-vote] .votes-count-number").html(@model.get("votes")["up_count"])

    convertMath: ->
      element = @$(".post-body")
      element.html DiscussionUtil.postMathJaxProcessor DiscussionUtil.markdownWithHighlight element.html()
      MathJax.Hub.Queue ["Typeset", MathJax.Hub, element[0]]

    renderResponses: ->
      DiscussionUtil.safeAjax
        url: "/courses/#{$$course_id}/discussion/forum/#{@model.get('commentable_id')}/threads/#{@model.id}"
        $loading: @$el
        success: (data, textStatus, xhr) =>
          @$el.find(".loading").remove()
          Content.loadContentInfos(data['annotated_content_info'])
          comments = new Comments(data['content']['children'])
          comments.each @renderResponse
          @trigger "thread:responses:rendered"

    renderResponse: (response) =>
      response.set('thread', @model)
      view = new ThreadResponseView(model: response)
      view.on "comment:add", @addComment
      view.render()
      @$el.find(".responses").append(view.el)

    addComment: =>
      @model.comment()

    toggleVote: (event) ->
      event.preventDefault()
      if window.user.voted(@model)
        @unvote()
      else
        @vote()

    toggleFollowing: (event) ->
      $elem = $(event.target)
      url = null
      console.log "follow"
      if not @model.get('subscribed')
        @model.follow()
        url = @model.urlFor("follow")
      else
        @model.unfollow()
        url = @model.urlFor("unfollow")
      DiscussionUtil.safeAjax
        $elem: $elem
        url: url
        type: "POST"

    vote: ->
      window.user.vote(@model)
      url = @model.urlFor("upvote")
      DiscussionUtil.safeAjax
        $elem: @$(".discussion-vote")
        url: url
        type: "POST"
        success: (response, textStatus) =>
          if textStatus == 'success'
            @model.set(response)

    unvote: ->
      window.user.unvote(@model)
      url = @model.urlFor("unvote")
      DiscussionUtil.safeAjax
        $elem: @$(".discussion-vote")
        url: url
        type: "POST"
        success: (response, textStatus) =>
          if textStatus == 'success'
            @model.set(response)

    submitComment: (event) ->
      event.preventDefault()
      url = @model.urlFor('reply')
      body = @getWmdContent("reply-body")
      return if not body.trim().length
      @setWmdContent("reply-body", "")
      comment = new Comment(body: body, created_at: (new Date()).toISOString(), username: window.user.get("username"), votes: { up_count: 0 }, endorsed: false, user_id: window.user.get("id"))
      comment.set('thread', @model.get('thread'))
      @renderResponse(comment)
      @model.addComment()

      DiscussionUtil.safeAjax
        $elem: $(event.target)
        url: url
        type: "POST"
        dataType: 'json'
        data:
          body: body
        success: (data, textStatus) =>
          comment.updateInfo(data.annotated_content_info)
          comment.set(data.content)

    edit: ->


    delete: (event) ->
      url = @model.urlFor('delete')
      if not @model.can('can_delete')
        return
      if not confirm "Are you sure to delete thread \"#{@model.get('title')}\"?"
        return
      @model.remove()
      @$el.empty()
      $elem = $(event.target)
      DiscussionUtil.safeAjax
        $elem: $elem
        url: url
        type: "POST"
        success: (response, textStatus) =>

    toggleClosed: (event) ->
      $elem = $(event.target)
      url = @model.urlFor('close')
      closed = @model.get('closed')
      data = { closed: not closed }
      DiscussionUtil.safeAjax
        $elem: $elem
        url: url
        data: data
        type: "POST"
        success: (response, textStatus) =>
          @model.set('closed', not closed)
          @model.set('ability', response.ability)

    toggleEndorse: (event) ->
      $elem = $(event.target)
      url = @model.urlFor('endorse')
      endorsed = @model.get('endorsed')
      data = { endorsed: not endorsed }
      DiscussionUtil.safeAjax
        $elem: $elem
        url: url
        data: data
        type: "POST"
        success: (response, textStatus) =>
          @model.set('endorsed', not endorsed)

    abbreviateBody: ->
      abbreviated = DiscussionUtil.abbreviateString @model.get('body'), 140
      @model.set('abbreviatedBody', abbreviated)

    expandPost: (event) ->
      @expanded = true
      @$el.addClass('expanded')
      @$el.find('.post-body').html(@model.get('body'))
      @convertMath()
      @$el.find('.expand-post').css('display', 'none')
      @$el.find('.collapse-post').css('display', 'block')
      @$el.find('.post-extended-content').show()
      @makeWmdEditor "reply-body"
      if @$el.find('.loading').length
        @renderResponses()

    collapsePost: (event) ->
      @expanded = false
      @$el.removeClass('expanded')
      @$el.find('.post-body').html(@model.get('abbreviatedBody'))
      @convertMath()
      @$el.find('.collapse-post').css('display', 'none')
      @$el.find('.post-extended-content').hide()
      @$el.find('.expand-post').css('display', 'block')
