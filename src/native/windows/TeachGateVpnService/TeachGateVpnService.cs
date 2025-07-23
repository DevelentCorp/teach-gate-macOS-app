using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Linq;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace TeachGateVpn
{
    public class TeachGateVpnService : ServiceBase
    {
        private const string EVENT_LOG_SOURCE = "TeachGateVpnService";
        private const string EVENT_LOG_NAME = "Application";
        private const string PIPE_NAME = "TeachGateVpnPipe";
        private const string TAP_DEVICE_NAME = "teachgate-tap0";

        private EventLog eventLog;
        private NamedPipeServerStream pipe;
        private bool IsConnected { get; set; }

        public TeachGateVpnService()
        {
            InitializeComponent();

            eventLog = new EventLog();
            if (!EventLog.SourceExists(EVENT_LOG_SOURCE))
            {
                EventLog.CreateEventSource(EVENT_LOG_SOURCE, EVENT_LOG_NAME);
            }
            eventLog.Source = EVENT_LOG_SOURCE;
            eventLog.Log = EVENT_LOG_NAME;
        }

        protected override void OnStart(string[] args)
        {
            eventLog.WriteEntry("TeachGateVpnService starting");
            CreatePipe();
        }

        protected override void OnStop()
        {
            eventLog.WriteEntry("TeachGateVpnService stopping");
            DestroyPipe();
        }

        private void CreatePipe()
        {
            var pipeSecurity = new PipeSecurity();
            pipeSecurity.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(
                WellKnownSidType.CreatorOwnerSid, null),
                PipeAccessRights.FullControl, AccessControlType.Allow));
            pipeSecurity.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(
                WellKnownSidType.AuthenticatedUserSid, null),
                PipeAccessRights.ReadWrite, AccessControlType.Allow));

            pipe = new NamedPipeServerStream(PIPE_NAME, PipeDirection.InOut, -1, PipeTransmissionMode.Message,
                                             PipeOptions.Asynchronous, 1024, 1024, pipeSecurity);
            pipe.BeginWaitForConnection(HandleConnection, null);
        }

        private void DestroyPipe()
        {
            if (pipe != null)
            {
                if (pipe.IsConnected)
                {
                    pipe.Disconnect();
                }
                pipe.Close();
                pipe = null;
            }
        }

        private void HandleConnection(IAsyncResult result)
        {
            try
            {
                pipe.EndWaitForConnection(result);
                // Keep the pipe connected to send connection status updates.
                while (pipe.IsConnected)
                {
                    // For now, we don't have a complex request/response system.
                    // We can add it later if needed.
                }
            }
            catch (Exception e)
            {
                eventLog.WriteEntry($"Failed to handle connection: {e.ToString()}", EventLogEntryType.Error);
            }
            finally
            {
                DestroyPipe();
                CreatePipe();
            }
        }

        public void Start(string config, int port)
        {
            IsConnected = true;
            eventLog.WriteEntry("VPN Started");
        }

        public void Stop()
        {
            IsConnected = false;
            eventLog.WriteEntry("VPN Stopped");
        }

        public void Disconnect()
        {
            IsConnected = false;
            eventLog.WriteEntry("VPN Disconnected");
        }

        public bool IsRunning()
        {
            return IsConnected;
        }

        private void InitializeComponent()
        {
            // 
            // TeachGateVpnService
            // 
            this.ServiceName = "TeachGateVpnService";
        }
    }
}