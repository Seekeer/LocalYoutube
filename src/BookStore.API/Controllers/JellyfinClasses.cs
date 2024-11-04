using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Reflection.PortableExecutable;
using System.Threading;
using System.Threading.Tasks;
using Google.Apis.YouTube.v3.Data;
using Jellyfin.Api.Attributes;
using Jellyfin.Api.Helpers;

//using Jellyfin.Api.Attributes;
//using Jellyfin.Api.Extensions;
//using Jellyfin.Api.Helpers;
//using Jellyfin.Api.ModelBinders;
//using Jellyfin.Extensions;
using MediaBrowser.Common.Api;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Net;
using MediaBrowser.Controller.Configuration;
using MediaBrowser.Controller.Dto;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.MediaEncoding;
using MediaBrowser.Controller.Streaming;
using MediaBrowser.MediaEncoding.Transcoding;
using MediaBrowser.Model.Configuration;
using MediaBrowser.Model.Dlna;
using MediaBrowser.Model.Dto;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.MediaInfo;
using MediaBrowser.Model.Net;
using MediaBrowser.Model.Querying;
using MediaBrowser.Model.Session;
using MediaToolkit.Options;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Polly;
using Sentry.Protocol;
using VkNet.Model;
using Xabe.FFmpeg.Streams.SubtitleStream;

namespace Jellyfin.Api.Controllers;

/// <summary>
/// The videos controller.
/// </summary>
public class VideosController : ControllerBase
{
    private readonly ILibraryManager _libraryManager;
    private readonly IUserManager _userManager;
    private readonly IDtoService _dtoService;
    private readonly IMediaSourceManager _mediaSourceManager;
    private readonly IServerConfigurationManager _serverConfigurationManager;
    private readonly IMediaEncoder _mediaEncoder;
    private readonly ITranscodeManager _transcodeManager;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly EncodingHelper _encodingHelper;

    private readonly TranscodingJobType _transcodingJobType = TranscodingJobType.Progressive;

    /// <summary>
    /// Initializes a new instance of the <see cref="VideosController"/> class.
    /// </summary>
    /// <param name="libraryManager">Instance of the <see cref="ILibraryManager"/> interface.</param>
    /// <param name="userManager">Instance of the <see cref="IUserManager"/> interface.</param>
    /// <param name="dtoService">Instance of the <see cref="IDtoService"/> interface.</param>
    /// <param name="mediaSourceManager">Instance of the <see cref="IMediaSourceManager"/> interface.</param>
    /// <param name="serverConfigurationManager">Instance of the <see cref="IServerConfigurationManager"/> interface.</param>
    /// <param name="mediaEncoder">Instance of the <see cref="IMediaEncoder"/> interface.</param>
    /// <param name="transcodeManager">Instance of the <see cref="ITranscodeManager"/> interface.</param>
    /// <param name="httpClientFactory">Instance of the <see cref="IHttpClientFactory"/> interface.</param>
    /// <param name="encodingHelper">Instance of <see cref="EncodingHelper"/>.</param>
    public VideosController(
        ILibraryManager libraryManager,
        IUserManager userManager,
        IDtoService dtoService,
        IMediaSourceManager mediaSourceManager,
        IServerConfigurationManager serverConfigurationManager,
        IMediaEncoder mediaEncoder,
        ITranscodeManager transcodeManager,
        IHttpClientFactory httpClientFactory,
        EncodingHelper encodingHelper)
    {
        _libraryManager = libraryManager;
        _userManager = userManager;
        _dtoService = dtoService;
        _mediaSourceManager = mediaSourceManager;
        _serverConfigurationManager = serverConfigurationManager;
        _mediaEncoder = mediaEncoder;
        _transcodeManager = transcodeManager;
        _httpClientFactory = httpClientFactory;
        _encodingHelper = encodingHelper;
    }

    [HttpGet]
    [AllowAnonymous]
    [HttpHead]
    public async Task<ActionResult> ConvertVideoById(int fileId,
                //[FromRoute, Required] Guid itemId,
        [FromQuery][RegularExpression(EncodingHelper.ValidationRegex)] string? container,
        [FromQuery] bool? @static,
        [FromQuery] string? @params,
        [FromQuery] string? tag,
        [FromQuery, ParameterObsolete] string? deviceProfileId,
        [FromQuery] string? playSessionId,
        [FromQuery][RegularExpression(EncodingHelper.ValidationRegex)] string? segmentContainer,
        [FromQuery] int? segmentLength,
        [FromQuery] int? minSegments,
        [FromQuery] string? mediaSourceId,
        [FromQuery] string? deviceId,
        [FromQuery][RegularExpression(EncodingHelper.ValidationRegex)] string? audioCodec,
        [FromQuery] bool? enableAutoStreamCopy,
        [FromQuery] bool? allowVideoStreamCopy,
        [FromQuery] bool? allowAudioStreamCopy,
        [FromQuery] bool? breakOnNonKeyFrames,
        [FromQuery] int? audioSampleRate,
        [FromQuery] int? maxAudioBitDepth,
        [FromQuery] int? audioBitRate,
        [FromQuery] int? audioChannels,
        [FromQuery] int? maxAudioChannels,
        [FromQuery] string? profile,
        [FromQuery] string? level,
        [FromQuery] float? framerate,
        [FromQuery] float? maxFramerate,
        [FromQuery] bool? copyTimestamps,
        [FromQuery] long? startTimeTicks,
        [FromQuery] int? width,
        [FromQuery] int? height,
        [FromQuery] int? maxWidth,
        [FromQuery] int? maxHeight,
        [FromQuery] int? videoBitRate,
        [FromQuery] int? subtitleStreamIndex,
        [FromQuery] SubtitleDeliveryMethod? subtitleMethod,
        [FromQuery] int? maxRefFrames,
        [FromQuery] int? maxVideoBitDepth,
        [FromQuery] bool? requireAvc,
        [FromQuery] bool? deInterlace,
        [FromQuery] bool? requireNonAnamorphic,
        [FromQuery] int? transcodingMaxAudioChannels,
        [FromQuery] int? cpuCoreLimit,
        [FromQuery] string? liveStreamId,
        [FromQuery] bool? enableMpegtsM2TsMode,
        [FromQuery][RegularExpression(EncodingHelper.ValidationRegex)] string? videoCodec,
        [FromQuery][RegularExpression(EncodingHelper.ValidationRegex)] string? subtitleCodec,
        [FromQuery] string? transcodeReasons,
        [FromQuery] int? audioStreamIndex,
        [FromQuery] int? videoStreamIndex,
        [FromQuery] EncodingContext? context,
        [FromQuery] Dictionary<string, string> streamOptions,
        [FromQuery] bool enableAudioVbrEncoding = true)
    {
        var cancellationTokenSource = new CancellationTokenSource();
        var isHeadRequest = Request.Method == System.Net.WebRequestMethods.Http.Head;
        var streamingRequest = new VideoRequestDto
        {
            Id = Guid.NewGuid(),
            Container = container,
            Static = @static ?? false,
            Params = @params,
            Tag = tag,
            PlaySessionId = playSessionId,
            SegmentContainer = segmentContainer,
            SegmentLength = segmentLength,
            MinSegments = minSegments,
            MediaSourceId = mediaSourceId,
            DeviceId = deviceId,
            AudioCodec = audioCodec,
            EnableAutoStreamCopy = enableAutoStreamCopy ?? true,
            AllowAudioStreamCopy = allowAudioStreamCopy ?? true,
            AllowVideoStreamCopy = allowVideoStreamCopy ?? true,
            BreakOnNonKeyFrames = breakOnNonKeyFrames ?? false,
            AudioSampleRate = audioSampleRate,
            MaxAudioChannels = maxAudioChannels,
            AudioBitRate = audioBitRate,
            MaxAudioBitDepth = maxAudioBitDepth,
            AudioChannels = audioChannels,
            Profile = profile,
            Level = level,
            Framerate = framerate,
            MaxFramerate = maxFramerate,
            CopyTimestamps = copyTimestamps ?? false,
            StartTimeTicks = startTimeTicks,
            Width = width,
            Height = height,
            MaxWidth = maxWidth,
            MaxHeight = maxHeight,
            VideoBitRate = videoBitRate,
            SubtitleStreamIndex = subtitleStreamIndex,
            SubtitleMethod = subtitleMethod ?? SubtitleDeliveryMethod.Encode,
            MaxRefFrames = maxRefFrames,
            MaxVideoBitDepth = maxVideoBitDepth,
            RequireAvc = requireAvc ?? false,
            DeInterlace = deInterlace ?? false,
            RequireNonAnamorphic = requireNonAnamorphic ?? false,
            TranscodingMaxAudioChannels = transcodingMaxAudioChannels,
            CpuCoreLimit = cpuCoreLimit,
            LiveStreamId = liveStreamId,
            EnableMpegtsM2TsMode = enableMpegtsM2TsMode ?? false,
            VideoCodec = videoCodec,
            SubtitleCodec = subtitleCodec,
            TranscodeReasons = transcodeReasons,
            AudioStreamIndex = audioStreamIndex,
            VideoStreamIndex = videoStreamIndex,
            Context = context ?? EncodingContext.Streaming,
            StreamOptions = streamOptions,
            EnableAudioVbrEncoding = enableAudioVbrEncoding
        };

        var state = await StreamingHelpers.GetStreamingState(
            streamingRequest,
            HttpContext,
            _mediaSourceManager,
            _userManager,
            _libraryManager,
            _serverConfigurationManager,
            _mediaEncoder,
            _encodingHelper,
            _transcodeManager,
            _transcodingJobType,
            cancellationTokenSource.Token)
        .ConfigureAwait(false);

        var encodingOptions = _serverConfigurationManager.GetEncodingOptions();
        var ffmpegCommandLineArguments = _encodingHelper.GetProgressiveVideoFullCommandLine(state, encodingOptions, EncoderPreset.superfast);
        return await FileStreamResponseHelpers.GetTranscodedFile(
            state,
            isHeadRequest,
            HttpContext,
            _transcodeManager,
            ffmpegCommandLineArguments,
            _transcodingJobType,
            cancellationTokenSource).ConfigureAwait(false);

        //using (await _transcodeManager.LockAsync(outputPath, cancellationTokenSource.Token).ConfigureAwait(false))
        //{
        //    TranscodingJob? job;
        //    //if (!File.Exists(outputPath))
        //    {
        //        job = await _transcodeManager.StartFfMpeg(
        //            state,
        //            outputPath,
        //            ffmpegCommandLineArguments,
        //            HttpContext.User.GetUserId(),
        //            _transcodingJobType,
        //            cancellationTokenSource).ConfigureAwait(false);
        //    }
        //    //else
        //    //{
        //    //    job = transcodeManager.OnTranscodeBeginRequest(outputPath, TranscodingJobType.Progressive);
        //    //    state.Dispose();
        //    //}

        //    var stream = new ProgressiveFileStream(outputPath, job, _transcodeManager);
        //    return new FileStreamResult(stream, "application/octet-stream");
        //}
    }


    [HttpGet]
    [AllowAnonymous]
    [HttpHead]
    public async Task<ActionResult> ConvertVideoById(int fileId)
    {
        var outputPath = "";
        var cancellationTokenSource = new CancellationTokenSource();
        using (await _transcodeManager.LockAsync(outputPath, cancellationTokenSource.Token).ConfigureAwait(false))
        {
            TranscodingJob? job;
            //if (!File.Exists(outputPath))
            {
                job = await _transcodeManager.StartFfMpeg(
                    state,
                    outputPath,
                    ffmpegCommandLineArguments,
                    HttpContext.User.GetUserId(),
                    _transcodingJobType,
                    cancellationTokenSource).ConfigureAwait(false);
            }
            //else
            //{
            //    job = transcodeManager.OnTranscodeBeginRequest(outputPath, TranscodingJobType.Progressive);
            //    state.Dispose();
            //}

            var stream = new ProgressiveFileStream(outputPath, job, _transcodeManager);
            return new FileStreamResult(stream, "application/octet-stream");
        }
    }
}

